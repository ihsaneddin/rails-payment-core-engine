class PaymentPackageProductValue < ApplicationRecord

  belongs_to :product
  belongs_to :payment_package, class_name: "Product::PaymentPackage", foreign_key: "payment_package_id"

end