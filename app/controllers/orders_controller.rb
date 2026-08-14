class OrdersController < AuthenticatedController
  before_action :set_order, only: %i[show cancel force_cancel refund]

  def index
    authorize Order
    @orders = Current.business.orders.recent.includes(:delivery).limit(50)
  end

  def show
    authorize @order
    @order_events = @order.order_events.order(created_at: :desc)
  end

  def cancel
    authorize @order, :cancel?
    OrderLifecycle.new(@order, current_user).cancel!
    redirect_to orders_path, notice: t("orders.cancelled")
  rescue OrderLifecycle::IllegalTransition
    redirect_to @order, alert: t("orders.cannot_cancel")
  end

  def force_cancel
    authorize @order, :cancel?
    OrderLifecycle.new(@order, current_user).cancel!(force: true)
    redirect_to orders_path, notice: t("orders.cancelled_override")
  rescue OrderLifecycle::IllegalTransition
    redirect_to @order, alert: t("orders.cannot_cancel")
  end

  def refund
    authorize @order, :refund?
    OrderLifecycle.new(@order, current_user).refund!
    redirect_to @order, notice: t("orders.refunded")
  rescue OrderLifecycle::IllegalTransition
    redirect_to @order, alert: t("orders.cannot_refund")
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:id])
  end
end
