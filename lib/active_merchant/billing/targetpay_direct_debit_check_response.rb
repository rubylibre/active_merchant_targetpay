module ActiveMerchant
  module Billing
    class TargetpayDirectDebitCheckResponse < Response

      def open?
        @message[0..5] == "000001"
      end
      
      def processing?
        @message[0..5] == "000002"
      end
      
      def failure?
        @message[0..5] == "000003"
      end
      
      def chargeback?
        @message[0..5] == "000004"
      end
      
      def redeemed?
        @message[0..5] == "TP0014"
      end
    end
  end
end
