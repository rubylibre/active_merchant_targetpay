require 'digest/sha1'

module ActiveMerchant
  module Billing
    class TargetpayDirectDebitGateway < Gateway

      # url will be completed below
      URL = "https://www.targetpay.com/directdebit/"

      def initialize(options = {})
        requires!(options, :rtlo, :salt)
        @options = options
        super
      end

      def setup_purchase(money, options)
        requires!(options, :cbank, :cname, :description, :reporturl, :securitylevel, :userip, :mandate, :mandatestart)

        raise ArgumentError.new("money should be >= EUR 1,00")                  if money < 100
        raise ArgumentError.new("money should be <= EUR 1000,00")               if money > 100000
        # raise ArgumentError.new("cbank should =~ /[0-9]+/")                     if !(options[:cbank] =~ /^[0-9]+$/)
        raise ArgumentError.new("cname is blank")                               if options[:cname].blank?
        raise ArgumentError.new("description should =~ /^[0-9A-Z\ ]{1,32}$/i")  if !(options[:description] =~ /^[0-9A-Z\ ]{1,32}$/i)
        raise ArgumentError.new("reporturl is blank")                           if options[:reporturl].blank?
        raise ArgumentError.new("securitylevel should be an Integer")           if !options[:securitylevel].kind_of?(Integer)
        raise ArgumentError.new("userip is blank")                              if options[:userip].blank?
        raise ArgumentError.new("mandate is blank")                             if options[:mandate].blank?
        raise ArgumentError.new("mandatestart is blank")                        if options[:mandatestart].blank?

        @response = build_start_response(commit('start', {
          :amount         => money,
          :cbank          => options[:cbank],
          :cname          => CGI::escape(options[:cname]),
          :country        => "NL",
          :description    => CGI::escape(options[:description]),
          :reporturl      => options[:reporturl],
          :rtlo           => @options[:rtlo],
          :salt           => @options[:salt],
          :securitylevel  => options[:securitylevel],
          :test           => ActiveMerchant::Billing::Base.test? ? "1" : "0",
          :userip         => options[:userip],
          :mandate        => options[:mandate],
          :mandatestart   => options[:mandatestart]
        }))
      end

      def details_for(token)
        build_check_response(commit('check', {
          :checksum => Digest::MD5.hexdigest(token + @options[:rtlo] + @options[:salt]),
          :once     => "1",
          :rtlo     => @options[:rtlo],
          :trxid    => token
        }))
      end

      private

      def commit(action, params)
        url   = URL + action + "?#{params.collect { |k,v| "#{k}=#{v}" }.join("&") }"
        uri   = URI.parse(url)
        http  = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.get(uri.request_uri).body
      end

      def build_start_response(response)
        params = {}
        message = response
        success = false
        if !response.blank? and response[0..5] == "000000"
          success = true
          args = response[7..-1].split("|")
          params[:trxid] = args[1]
        end
        TargetpayDirectDebitStartResponse.new(success, message, params)
      end

      def build_check_response(response)
        message = response
        success = false
        if response[0..5] == "000000"
          success = true
        end
        TargetpayDirectDebitCheckResponse.new(success, message)
      end
    end
  end
end
