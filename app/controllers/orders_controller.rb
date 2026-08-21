class OrdersController < AuthenticatedController
  before_action :set_order, only: %i[show cancel force_cancel refund out_for_delivery delivered]

  def index
    authorize Order
    @orders = Current.business.orders.recent.includes(:delivery)
    @orders = @orders.where(status: params[:status]) if params[:status].present?
    @orders = @orders.limit(50)
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

  def out_for_delivery
    authorize @order, :mark_out_for_delivery?
    return redirect_to(@order, alert: t("orders.delivery_not_updated")) unless @order.delivery
    return redirect_to(@order, alert: t("orders.delivery_not_updated")) if @order.cancelled? || @order.refunded?

    @order.delivery.update!(status: :out_for_delivery)
    redirect_to @order, notice: t("orders.delivery_out_notice")
  rescue ActiveRecord::RecordInvalid
    redirect_to @order, alert: t("orders.delivery_not_updated")
  end

  def delivered
    authorize @order, :mark_delivered?
    return redirect_to(@order, alert: t("orders.delivery_not_updated")) unless @order.delivery
    return redirect_to(@order, alert: t("orders.delivery_not_updated")) if @order.cancelled? || @order.refunded?

    @order.delivery.update!(status: :delivered)
    redirect_to @order, notice: t("orders.delivery_delivered_notice")
  rescue ActiveRecord::RecordInvalid
    redirect_to @order, alert: t("orders.delivery_not_updated")
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:id])
  end
end
