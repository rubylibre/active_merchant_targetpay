module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TargetpayIdealFetchResponse < Response
      def token
        @params['transactionid']
      end
      
      def url
        @params['url']
      end
    end
  end
end
