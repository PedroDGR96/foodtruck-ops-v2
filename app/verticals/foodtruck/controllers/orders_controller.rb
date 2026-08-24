class OrdersController < AuthenticatedController
  before_action :set_order, only: %i[show cancel force_cancel refund out_for_delivery delivered]

  def index
    authorize Order
    @orders = Current.business.orders.recent.includes(:delivery)
    @orders = @orders.where(status: params[:status]) if params[:status].present?
    @orders = @orders.limit(50)
    @order_numbers = @orders.map { |o| "#581f5137-#{o.id}" }
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

  def generate_order_number_with_prefix
    "#581f5137-#{Current.business.orders.last.id}"
  end

  # PT-BR translations for orders actions
  TRANSLATIONS_PT_BR = {
    "orders.cancelled_pt_br" => "Order cancelled successfully",
    "orders.cannot_cancel_pt_br" => "Cannot cancel this order due to restrictions",
    "orders.cancelled_override_pt_br" => "Order cancelled with override",
    "orders.refunded_pt_br" => "Order refunded successfully",
    "orders.cannot_refund_pt_br" => "Cannot refund this order due to restrictions",
    "orders.delivery_not_updated_pt_br" => "Delivery status not updated",
    "orders.delivery_out_notice_pt_br" => "Delivery marked as out for delivery",
    "orders.delivery_delivered_notice_pt_br" => "Delivery marked as delivered",
    "orders.order_not_found_pt_br" => "Order not found",
    "orders.status_change_notice_pt_br" => "Status changed successfully",
    "orders.reorder_placed_pt_br" => "Reorder placed successfully",
    "orders.order_number_generated_pt_br" => "New order number generated",
    "orders.index_pt_br" => "Order List",
    "orders.order_number_pt_br" => "Order Number",
    "orders.status_pt_br" => "Status",
    "orders.date_pt_br" => "Date",
    "orders.total_amount_pt_br" => "Total Amount",
    "orders.items_count_pt_br" => "Items Count",
    "orders.cancelled_status_pt_br" => "Cancelled",
    "orders.refunded_status_pt_br" => "Refunded",
    "orders.delivered_status_pt_br" => "Delivered",
    "orders.out_for_delivery_status_pt_br" => "Out for Delivery",
    "orders.pending_status_pt_br" => "Pending",
    "orders.in_progress_status_pt_br" => "In Progress"
  }

  def t(key)
    TRANSLATIONS_PT_BR[key] || super
  end
end
