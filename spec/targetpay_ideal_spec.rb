require "spec_helper.rb"

describe "TargetPay iDeal implementation for ActiveMerchant" do
  
  it "should create a new billing gateway with a required partner id" do
    ActiveMerchant::Billing::TargetpayIdealGateway.new(:rtlo => "123456").should be_kind_of(ActiveMerchant::Billing::TargetpayIdealGateway)
  end

  it "should throw an error if a gateway is created without a rtlo" do
    lambda {
      ActiveMerchant::Billing::TargetpayIdealGateway.new
    }.should raise_error(ArgumentError)
  end
  
  context "setup transaction" do
    
    before do
      @bank        = "0721"
      @description = "This is a test transaction"
      @reporturl   = "http://www.example.com/targetpay/report"
      @returnurl   = "http://www.example.com/targetpay/return"
      @rtlo        = "123456"
      @gateway     = ActiveMerchant::Billing::TargetpayIdealGateway.new(:rtlo => @rtlo)
    end
    
    it "should create a new purchase via the Targetpay API" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000000 0020000371938207|https://ideal.ing.nl/internetbankieren/SesamLoginServlet?sessie=ideal&trxid=0020000371938207&random=744aec44e3d2fdc')
      
      http_mock.should_receive(:get) do |url|
        { :bank => @bank, :description => CGI::escape(@description), :reporturl => @reporturl, :returnurl => @returnurl, :rtlo => @rtlo }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      response = @gateway.setup_purchase(1000, {
        :bank        => @bank,
        :description => @description,
        :reporturl   => @reporturl,
        :returnurl   => @returnurl
      })
      
      response.success?.should == true
      response.token.should == "0020000371938207"
      response.message.should == "000000 0020000371938207|https://ideal.ing.nl/internetbankieren/SesamLoginServlet?sessie=ideal&trxid=0020000371938207&random=744aec44e3d2fdc"
      @gateway.redirect_url_for(response.token).should == "https://ideal.ing.nl/internetbankieren/SesamLoginServlet?sessie=ideal&trxid=0020000371938207&random=744aec44e3d2fdc"
    end
    it "should return information about the error Targetpay is throwing" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('SO1200 Systeem te druk. Probeer later nogmaals')
      
      http_mock.should_receive(:get).and_return(response_mock)
      
      response = @gateway.setup_purchase(1000, {
        :bank        => @bank,
        :description => @description,
        :reporturl   => @reporturl,
        :returnurl   => @returnurl
      })
      response.success?.should == false
      response.message.should == "SO1200 Systeem te druk. Probeer later nogmaals"
    end

    it "should not allow a purchase without a bank" do
      lambda {
        @gateway.setup_purchase(1000, {
          :description => @description,
          :reporturl   => @reporturl,
          :returnurl   => @returnurl
        })
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a description" do
      lambda {
        @gateway.setup_purchase(1000, {
          :bank        => @bank,
          :reporturl   => @reporturl,
          :returnurl   => @returnurl
        })
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a reporturl" do
      lambda {
        @gateway.setup_purchase(1000, {
          :bank        => @bank,
          :description => @description,
          :returnurl   => @returnurl
        })
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a returnurl" do
      lambda {
        @gateway.setup_purchase(1000, {
          :bank        => @bank,
          :description => @description,
          :reporturl   => @reporturl
        })
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase if money < 100" do
      lambda {
        @gateway.setup_purchase(99, {
          :bank        => @bank,
          :description => @description,
          :reporturl   => @reporturl,
          :returnurl   => @returnurl
        })
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase if money > 1000000" do
      lambda {
        @gateway.setup_purchase(1000001, {
          :bank        => @bank,
          :description => @description,
          :reporturl   => @reporturl,
          :returnurl   => @returnurl
        })
      }.should raise_error(ArgumentError)
    end    
  end
  
  context "check transaction" do
    
    before do
      @rtlo    = 123456
      @trxid   = "1234567890"
      @gateway = ActiveMerchant::Billing::TargetpayIdealGateway.new(:rtlo => @rtlo)
    end
    
    it "should return success if transaction is paid" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000000 OK')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == true
      details_response.message.should == "000000 OK"
    end
    it "should return information about the error Targetpay is throwing" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('TP0011 Transactie is geannuleerd')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == false
      details_response.message.should == "TP0011 Transactie is geannuleerd"
    end
  end
end
