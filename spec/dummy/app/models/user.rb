class User < ApplicationRecord

  payment_method_holder do
    name :name
    email :email
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