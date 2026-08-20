class HomeController < AuthenticatedController
  def index
    authorize :home, :index?
    @report = DailyReport.call(Current.business)
    @active_orders = Current.business.orders.active.count
    @kitchen_queue = Current.business.orders.kitchen_queue.count
    @open_shift = CashRegister.open.find_by(user: current_user) if current_user.cashier?

    zone = Current.business.timezone ? ActiveSupport::TimeZone[Current.business.timezone] : Time.zone
    @weekly_revenue = Current.business.payments
      .where(status: "succeeded", created_at: 7.days.ago.beginning_of_day..zone.now.end_of_day)
      .sum(:amount)
    @weekly_orders = Current.business.orders
      .where(status: %w[paid in_kitchen ready completed], created_at: 7.days.ago.beginning_of_day..zone.now.end_of_day)
      .count
  end
end
