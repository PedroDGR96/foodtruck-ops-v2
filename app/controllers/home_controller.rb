class HomeController < AuthenticatedController
  def index
    authorize :home, :index?
    @report = DailyReport.call(Current.business)
    @active_orders = Current.business.orders.active.count
    @kitchen_queue = Current.business.orders.kitchen_queue.count
    @open_shift = CashRegister.open.find_by(user: current_user) if current_user.cashier?
  end
end
