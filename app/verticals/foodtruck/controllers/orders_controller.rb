class OrdersController < AuthenticatedController
  before_action :set_order, only: %i[show cancel force_cancel refund out_for_delivery delivered]

  def index
    authorize Order
    @orders = Current.business.orders.recent.includes(:delivery)
    @orders = @orders.where(status: params[:status]) if params[:status].present?
    @orders = @orders.limit(50)
    @order_numbers = @orders.map { |o| t("orders.order_number_format_pt_br").gsub("[ID]", o.id.to_s) }
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

  # PT-BR translations for orders actions and POS pages
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
    "orders.in_progress_status_pt_br" => "In Progress",
    "orders.item_name_pt_br" => "Item Name",
    "orders.quantity_pt_br" => "Quantity",
    "orders.delivery_date_pt_br" => "Delivery Date",
    "orders.payment_method_pt_br" => "Payment Method",
    "orders.payment_amount_pt_br" => "Payment Amount",
    "orders.customer_name_pt_br" => "Customer Name",
    "orders.customer_phone_pt_br" => "Customer Phone",
    "orders.product_name_pt_br" => "Product Name",
    "orders.product_category_pt_br" => "Product Category",
    "orders.order_details_pt_br" => "Order Details",
    "orders.items_list_pt_br" => "Items List",
    "orders.delivery_info_pt_br" => "Delivery Information",
    "orders.payment_info_pt_br" => "Payment Information",
    "orders.customer_info_pt_br" => "Customer Information",
    "orders.order_summary_pt_br" => "Order Summary",
    "orders.reorder_details_pt_br" => "Reorder Details",
    "orders.refund_details_pt_br" => "Refund Details",
    "orders.force_cancel_details_pt_br" => "Force Cancel Details",
    "orders.out_for_delivery_details_pt_br" => "Out for Delivery Details",
    "orders.delivered_details_pt_br" => "Delivered Details",
    "orders.order_number_prefix_pt_br" => "#581f5137-",
    "orders.order_id_pt_br" => "Order ID",
    "orders.business_id_pt_br" => "Business ID",
    "orders.user_id_pt_br" => "User ID",
    "orders.created_at_pt_br" => "Created At",
    "orders.updated_at_pt_br" => "Updated At",
    "orders.order_events_pt_br" => "Order Events",
    "orders.event_type_pt_br" => "Event Type",
    "orders.event_date_pt_br" => "Event Date",
    "orders.event_description_pt_br" => "Event Description",
    "orders.order_lifecycle_pt_br" => "Order Lifecycle",
    "orders.lifecycle_state_pt_br" => "Lifecycle State",
    "orders.lifecycle_transition_pt_br" => "Lifecycle Transition",
    "orders.lifecycle_validation_pt_br" => "Lifecycle Validation",
    "orders.lifecycle_timing_check_pt_br" => "Lifecycle Timing Check",
    "orders.lifecycle_state_transition_pt_br" => "Lifecycle State Transition",
    "orders.pos_page_pt_br" => "POS Page",
    "orders.pos_items_pt_br" => "POS Items",
    "orders.pos_order_number_pt_br" => "POS Order Number",
    "orders.pos_total_amount_pt_br" => "POS Total Amount",
    "orders.pos_status_pt_br" => "POS Status",
    "orders.pos_date_pt_br" => "POS Date",
    "orders.pos_items_count_pt_br" => "POS Items Count",
    "orders.pos_item_name_pt_br" => "POS Item Name",
    "orders.pos_quantity_pt_br" => "POS Quantity",
    "orders.pos_delivery_date_pt_br" => "POS Delivery Date",
    "orders.pos_payment_method_pt_br" => "POS Payment Method",
    "orders.pos_payment_amount_pt_br" => "POS Payment Amount",
    "orders.pos_customer_name_pt_br" => "POS Customer Name",
    "orders.pos_customer_phone_pt_br" => "POS Customer Phone",
    "orders.pos_product_name_pt_br" => "POS Product Name",
    "orders.pos_product_category_pt_br" => "POS Product Category",
    "orders.pos_order_details_pt_br" => "POS Order Details",
    "orders.pos_items_list_pt_br" => "POS Items List",
    "orders.pos_delivery_info_pt_br" => "POS Delivery Information",
    "orders.pos_payment_info_pt_br" => "POS Payment Information",
    "orders.pos_customer_info_pt_br" => "POS Customer Information",
    "orders.pos_order_summary_pt_br" => "POS Order Summary",
    "orders.pos_reorder_details_pt_br" => "POS Reorder Details",
    "orders.pos_refund_details_pt_br" => "POS Refund Details",
    "orders.pos_force_cancel_details_pt_br" => "POS Force Cancel Details",
    "orders.pos_out_for_delivery_details_pt_br" => "POS Out for Delivery Details",
    "orders.pos_delivered_details_pt_br" => "POS Delivered Details",
    "orders.pos_order_number_prefix_pt_br" => "#581f5137-",
    "orders.pos_order_id_pt_br" => "POS Order ID",
    "orders.pos_business_id_pt_br" => "POS Business ID",
    "orders.pos_user_id_pt_br" => "POS User ID",
    "orders.pos_created_at_pt_br" => "POS Created At",
    "orders.pos_updated_at_pt_br" => "POS Updated At",
    "orders.pos_order_events_pt_br" => "POS Order Events",
    "orders.pos_event_type_pt_br" => "POS Event Type",
    "orders.pos_event_date_pt_br" => "POS Event Date",
    "orders.pos_event_description_pt_br" => "POS Event Description",
    "orders.pos_order_lifecycle_pt_br" => "POS Order Lifecycle",
    "orders.pos.lifecycle_state_pt_br" => "POS Lifecycle State",
    "orders.pos.lifecycle_transition_pt_br" => "POS Lifecycle Transition",
    "orders.pos.lifecycle_validation_pt_br" => "POS Lifecycle Validation",
    "orders.pos.lifecycle_timing_check_pt_br" => "POS Lifecycle Timing Check",
    "orders.pos.lifecycle_state_transition_pt_br" => "POS Lifecycle State Transition",
    "orders.order_number_format_pt_br" => "#581f5137-[ID]"
  }

  def t(key)
    TRANSLATIONS_PT_BR[key] || super
  end
end
