# Computes a customer's purchase history from their orders. A purchase is any
# order that left the cart and was not cancelled or refunded (see
# Order.purchases); drafts and abandoned carts never count.
class CustomerHistory
  def self.call(customer)
    new(customer).call
  end

  def initialize(customer)
    @customer = customer
  end

  def call
    self
  end

  def orders
    @orders ||= customer.orders.purchases.recent.to_a
  end

  def order_count
    orders.size
  end

  def total_spent
    orders.sum(&:total).round(2)
  end

  def average_spend
    return 0.0 if order_count.zero?

    (total_spent / order_count).round(2)
  end

  def last_order
    orders.first
  end

  private

  attr_reader :customer
end
