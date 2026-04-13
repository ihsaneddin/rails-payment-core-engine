class Product::PaymentPackage < Product
  class Attributes < Product::Attributes
    attribute :additonal_information, :string
    attribute :amount_per_quantity, :decimal, precision: 12, scale: 2, default: 1
    attribute :item_cost_per_quantity, :decimal, precision: 12, scale: 2, default: 1
    attribute :disallow_purchase_on_item_ids, array: true, default: []
    attribute :allow_purchase_on_any_item, :boolean, default: true
    attribute :will_be_expired, :boolean, default: false
    attribute :will_expires_at_unit, :string, default: 'day'
    attribute :will_expires_at_time, :datetime
    attribute :will_expires_at_amount, :integer
    attribute :currency, :string, default: 'Ringgit Malaysian'
    attribute :custom_value, default: true
  end

  custom_attributes_definition :data, Attributes, accessor: true, prefix: ''

  after_create do
    self.disallow_purchase_on_item_ids ||= []
    self.disallow_purchase_on_item_ids << id
    self.disallow_purchase_on_item_ids.uniq!
    save!
  end

  has_many :product_values, class_name: 'PaymentPackageProductValue', foreign_key: :payment_package_id,
                            inverse_of: :payment_package
  has_many :products, through: :product_values, source: :product

  accepts_nested_attributes_for :product_values, allow_destroy: true, reject_if: :all_blank

  validates :amount_per_quantity, presence: true, numericality: { greater_than: 0, allow_blank: true }
  validates :item_cost_per_quantity, presence: true, numericality: { greater_than: 0, allow_blank: true }
  validates :will_expires_at_unit, inclusion: { in: %w[day month year] }, if: :will_be_expired
  validates :will_expires_at_amount, numericality: { greater_than: 0 }, if: :will_be_expired
  validates :will_expires_at_time, timeliness: { type: :datetime, after: :today }, if: :will_be_expired
  validates :will_expires_at_amount, absence: true, if: :will_expires_at_time

  order_core_line_item_callback :validate do |line_item|
    # line_item.errors.add(:item, :invalid) #unless line_item.item.class == LineItem::PaymentPackage
  end

  def process(customer, quantity: 1, reference: nil)
    currency = get_or_create_ewallet_currency
    account = get_or_create_ewallet_account(customer)
    amount = amount_per_quantity * quantity
    Ewallet::Entry.deposit(amount: amount, target_account_id: account.id, reference: reference, currency: currency)
  end

  def get_or_create_ewallet_account(customer)
    curr = get_or_create_ewallet_currency
    wallet = customer.current_ewallet
    if will_be_expired
      expiration_time = will_expires_at_time || (DateTime.now + will_expires_at_amount.send(will_expires_at_unit))
      account = wallet.accounts.where(currency: curr, limited_time: true,
                                      should_expire_at: expiration_time).first
      account ||= wallet.accounts.create(currency: curr, limited_time: true,
                                         should_expire_at: expiration_time)
      account
    else
      account = wallet.accounts.where(currency: curr).first
      account ||= wallet.accounts.create(currency: curr)
      account
    end
  end

  def get_or_create_ewallet_currency
    return @curr if @curr

    issuer = Ewallet.config.issuer.default
    issuer = issuer.call if issuer.is_a?(Proc)

    @curr = Ewallet::Currency.where(reference: self, name: currency, issuer: issuer).first
    @curr ||= Ewallet::Currency.create(reference: self, name: currency, issuer: issuer)
    @curr
  end

  def get_amount_per_quantity(payable)
    payables = []
    if payable.is_a?(Order)
      payables = payable.line_items
    elsif payable.is_a?(LineItem)
      payables << payable
    end
    payables.inject(0) { |sum, p| sum += p.payable_quantity * item_cost_per_quantity }
  end

  def get_value_of_product(product)
    product_values.where(product: product).first&.value
  end

  def could_be_use_on_product?(product)
    product_values.where(product: product).exists?
  end

  def allowed_to_be_purchased?(*items)
    items.all? { |item| !disallow_purchase_on_item_ids.compact.include?(item.id) }
  end

  payment_method_availability do |payment_method, _context|
    payment_method.method_type != 'payment_package'
  end

  def requires_payable?
    custom_value
  end
end
