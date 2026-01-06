module PaymentCore
  module PaymentMethods
    class Cash < ::PaymentCore::PaymentMethod

      self.method_type= "cash"

    end
  end
end
