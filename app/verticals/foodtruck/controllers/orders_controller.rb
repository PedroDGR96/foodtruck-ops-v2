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
    # Cancel action requires authorization and uses OrderLifecycle for the transition.
    # The lifecycle handles validation, timing checks, and state transitions.
    authorize @order, :cancel?
    OrderLifecycle.new(@order, current_user).cancel!
    redirect_to orders_path, notice: t("orders.cancelled_pt_br")
  rescue OrderLifecycle::IllegalTransition
    redirect_to @order, alert: t("orders.cannot_cancel_pt_br")
  end

  def force_cancel
    # Force cancel overrides lifecycle restrictions. Requires authorization and uses the same pattern as regular cancel.
    authorize @order, :cancel?
    OrderLifecycle.new(@order, current_user).cancel!(force: true)
    redirect_to orders_path, notice: t("orders.cancelled_override_pt_br")
  rescue OrderLifecycle::IllegalTransition
    redirect_to @order, alert: t("orders.cannot_cancel_pt_br")
  end

  def refund
    # Refund action requires authorization and uses OrderLifecycle for the transition.
    # The lifecycle handles validation, timing checks, and state transitions.
    authorize @order, :refund?
    OrderLifecycle.new(@order, current_user).refund!
    redirect_to @order, notice: t("orders.refunded_pt_br")
  rescue OrderLifecycle::IllegalTransition
    redirect_to @order, alert: t("orders.cannot_refund_pt_br")
  end

  def out_for_delivery
    # Delivery action requires authorization and updates the delivery status.
    # Specific guards: requires a delivery record, not cancelled/refunded.
    authorize @order, :mark_out_for_delivery?
    return redirect_to(@order, alert: t("orders.delivery_not_updated_pt_br")) unless @order.delivery
    return redirect_to(@order, alert: t("orders.delivery_not_updated_pt_br")) if @order.cancelled? || @order.refunded?

    @order.delivery.update!(status: :out_for_delivery)
    redirect_to @order, notice: t("orders.delivery_out_notice_pt_br")
  rescue ActiveRecord::RecordInvalid
    redirect_to @order, alert: t("orders.delivery_not_updated_pt_br")
  end

  def delivered
    # Delivery action requires authorization and updates the delivery status.
    # Specific guards: requires a delivery record, not cancelled/refunded.
    authorize @order, :mark_delivered?
    return redirect_to(@order, alert: t("orders.delivery_not_updated_pt_br")) unless @order.delivery
    return redirect_to(@order, alert: t("orders.delivery_not_updated_pt_br")) if @order.cancelled? || @order.refunded?

    @order.delivery.update!(status: :delivered)
    redirect_to @order, notice: t("orders.delivery_delivered_notice_pt_br")
  rescue ActiveRecord::RecordInvalid
    redirect_to @order, alert: t("orders.delivery_not_updated_pt_br")
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:id])
  end
end
