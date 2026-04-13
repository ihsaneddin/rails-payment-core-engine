class User < ApplicationRecord

  payment_method_holder do
    name :name
    email :email
    events do
      payment_method do
        updated do |_payment_method|
          update_column(:name, "payment_method_updated")
        end
      end
    end
  end

  order_customer do
    name :name
  end

  acts_as_ewallet_holder do
    prefix_number do
      "USER-"
    end
  end

end
