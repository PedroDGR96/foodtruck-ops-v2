class DailyReport
  Row = Struct.new(:product_name, :quantity, :total, keyword_init: true)

  def self.call(business, date = nil)
    new(business, date).to_h
  end

  def initialize(business, date = nil)
    @business = business
    @date = date
  end

  def to_h
    window = BusinessDay.window(business, date)
    orders = base_orders(window)

    {
      date: date,
      window: window,
      total_count: orders.count,
      gross_total: orders.sum(:total).to_d,
      refund_total: refund_total(window).to_d,
      by_method: by_method(orders),
      by_product: by_product(orders),
      shifts: shifts(window)
    }
  end

  private

  attr_reader :business, :date

  def base_orders(window)
    business.orders.purchases.where(created_at: window)
  end

  def refund_total(window)
    business.orders.where(status: :refunded, created_at: window).sum(:total)&.to_d || 0
  end

  def by_method(orders)
    Payment.includes(:order).where(order_id: orders.select(:id), status: :succeeded)
           .distinct(:order_id)
           .group(:method)
           .sum(:amount)
           .transform_values(&:to_d)
  end

  def by_product(orders)
    OrderItem.where(order_id: orders.select(:id))
             .group(:product_name)
             .order(Arel.sql("SUM(line_total) DESC"))
             .pluck(:product_name, Arel.sql("SUM(quantity)"), Arel.sql("SUM(line_total)"))
             .map { |name, qty, total| Row.new(product_name: name, quantity: qty.to_d, total: total.to_d) }
  end

  def shifts(window)
    business.cash_registers
            .where("opened_at < ? AND (closed_at IS NULL OR closed_at > ?)", window.last, window.first)
            .order(opened_at: :asc)
            .to_a
  end
end
