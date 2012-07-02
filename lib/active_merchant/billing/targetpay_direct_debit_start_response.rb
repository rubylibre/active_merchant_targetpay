module ActiveMerchant
  module Billing
    class TargetpayDirectDebitStartResponse < Response

      def token
        @params['trxid']
      end

      def account_number_check_failed?
        @message[0..5] == "TP1000"
      end

    end
  end
end
