require "spec_helper.rb"

describe "TargetPay Direct Debit implementation for ActiveMerchant" do
  
  it "should create a new billing gateway with a required partner id and salt" do
    ActiveMerchant::Billing::TargetpayDirectDebitGateway.new(:rtlo => "123456", :salt => "abcd").should be_kind_of(ActiveMerchant::Billing::TargetpayDirectDebitGateway)
  end

  it "should throw an error if a gateway is created without a rtlo and salt" do
    lambda {
      ActiveMerchant::Billing::TargetpayDirectDebitGateway.new
    }.should raise_error(ArgumentError)
  end

  context "setup transaction" do

    before do
      @rtlo     = "123456"
      @salt     = "abcd"
      @gateway  = ActiveMerchant::Billing::TargetpayDirectDebitGateway.new(:rtlo => @rtlo, :salt => @salt)
      @params   = { 
        :cbank => "123456789", 
        :cname => "Berend Botje",
        :description => "Test invoice 123",
        :reporturl => "http://www.example.com/targetpay/report",
        :retrymax => 3, 
        :securitylevel => 5, 
        :userip => "127.0.0.1"
      }
    end

    it "should create a new purchase via the Targetpay API" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)

      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000000 OK|a0b1c2d3e4f5g6h7i8j9')

      http_mock.should_receive(:get) do |url|
        @params.each do |param, value|
          if param == :cname or param == :description
            url.should include("#{param}=#{CGI::escape(value)}")
          else
            url.should include("#{param}=#{value}")
          end
        end
        response_mock
      end

      response = @gateway.setup_purchase(1000, @params)

      response.success?.should == true
      response.token.should == "a0b1c2d3e4f5g6h7i8j9"
      response.message.should == "000000 OK|a0b1c2d3e4f5g6h7i8j9"
    end
    it "should return information about the error Targetpay is throwing" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)

      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('TP1000 Refused: invalid bankaccount, fails 11-test')

      http_mock.should_receive(:get).and_return(response_mock)

      response = @gateway.setup_purchase(1000, @params)
      response.success?.should == false
      response.message.should == "TP1000 Refused: invalid bankaccount, fails 11-test"
    end

    it "should not allow a purchase without a cbank" do
      @params[:cbank] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a cname" do
      @params[:cname] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a description" do
      @params[:description] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a reporturl" do
      @params[:reporturl] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a retrymax" do
      @params[:retrymax] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a securitylevel" do
      @params[:securitylevel] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase without a userip" do
      @params[:userip] = nil
      lambda {
        @gateway.setup_purchase(1000, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase if money < 100" do
      lambda {
        @gateway.setup_purchase(99, @params)
      }.should raise_error(ArgumentError)
    end
    it "should not allow a purchase if money > 100000" do
      lambda {
        @gateway.setup_purchase(100001, @params)
      }.should raise_error(ArgumentError)
    end    
  end
  
  context "check transaction" do
    
    before do
      @rtlo     = "123456"
      @salt     = "abcd"
      @trxid    = "12345678"
      @gateway  = ActiveMerchant::Billing::TargetpayDirectDebitGateway.new(:rtlo => @rtlo, :salt => @salt)
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
    it "should return false is transaction is still open" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000001 Open')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == false
      details_response.message.should == "000001 Open"
      details_response.open?.should == true
      details_response.processing?.should == false
      details_response.failure?.should == false
      details_response.chargeback?.should == false
    end
    it "should return false is transaction is still processing" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000002 Processing')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == false
      details_response.message.should == "000002 Processing"
      details_response.open?.should == false
      details_response.processing?.should == true
      details_response.failure?.should == false
      details_response.chargeback?.should == false
    end
    it "should return false is transaction is a failure" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000003 Failure')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == false
      details_response.message.should == "000003 Failure"
      details_response.open?.should == false
      details_response.processing?.should == false
      details_response.failure?.should == true
      details_response.chargeback?.should == false
    end
    it "should return false is transaction is a chargeback" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('000004 Chargeback')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == false
      details_response.message.should == "000004 Chargeback"
      details_response.open?.should == false
      details_response.processing?.should == false
      details_response.failure?.should == false
      details_response.chargeback?.should == true
    end
    it "should return false is already redeemed" do
      http_mock = mock(Net::HTTP)      
      http_mock.should_receive(:use_ssl=).once.with(true)
      Net::HTTP.should_receive(:new).with("www.targetpay.com", 443).and_return(http_mock)
      
      response_mock = mock(Net::HTTPResponse)
      response_mock.should_receive(:body).and_return('TP0014 Already redeemed at XXXX-XX-XX XX:XX:XX')
      
      http_mock.should_receive(:get) do |url|
        { :once => "1", :rtlo => @rtlo, :trxid => @trxid }.each do |param, value|
          url.should include("#{param}=#{value}")
        end
        response_mock
      end
      
      details_response = @gateway.details_for(@trxid)
      details_response.success?.should == false
      details_response.message.should == "TP0014 Already redeemed at XXXX-XX-XX XX:XX:XX"
      details_response.redeemed?.should == true
    end
  end
end
