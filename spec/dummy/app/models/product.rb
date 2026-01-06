class Product < ApplicationRecord
  has_many :payment_package_product_values, class_name: 'PaymentPackageProductValue', foreign_key: :product_id
  has_many :payment_packages, through: :payment_package_product_values, source: :payment_package

  class Attributes
    include StoreModel::Model

    attribute :additonal_information, :string
  end

  custom_attributes_definition :data, Attributes, accessor: true, prefix: ''

  order_item do
    sku :sku
    name :name
    description ''
    price :price
    unit_quantity :unit_quantity
    set_unit_quantity do |_line_item|
      unit_quantity || order_item_unit_quantity
    end
    set_quantity do |line_item|
      line_item.quantity
    end
  end

  payable

  payment_method_availability method_types: :payment_package do |payment_method, _context|
    package = payment_method.package
    package.allow_purchase_on_any_item || package.could_be_use_on_product?(self)
  end

  def payment_package_value(payment_package)
    payment_package_product_values.where(payment_package: payment_package).first&.value
  end
end
