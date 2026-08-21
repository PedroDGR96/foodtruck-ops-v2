class HomeController < AuthenticatedController
  def index
    authorize :home, :index?
    @report = DailyReport.call(Current.business)
    @active_orders = Current.business.orders.active.count
    @kitchen_queue = Current.business.orders.kitchen_queue.count
    @open_shift = CashRegister.open.find_by(user: current_user) if current_user.cashier?

    last_week = 7.days.ago.beginning_of_day..Date.current.end_of_day
    @weekly_revenue = Current.business.payments.where(status: :succeeded, created_at: last_week).sum(:amount)
    @weekly_orders = Current.business.orders.purchases.where(created_at: last_week).count
  end
end
