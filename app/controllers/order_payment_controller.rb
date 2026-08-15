class OrderPaymentController < AuthenticatedController
  before_action :set_order

  def show
    authorize @order, :pay?
    @step = params[:step]&.to_i || 1
    if [@step, @step + 1].cover?(@order.payment_status.to_s)
      @payment = build_payment_for_step(@order, @step)
    else
      redirect_to new_order_payment_path(@order), alert: "Invalid payment step"
    end
  end

  def create
    authorize @order, :pay?
    order = params[:order]
    amount = params[:amount]&.to_f || 0

    if amount > 0
      record_payment(order.id, amount)
      redirect_to new_order_payment_path(order), notice: "Payment recorded"
    else
      redirect_to new_order_payment_path(order), alert: "Amount must be greater than zero"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_order_payment_path(order), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:order_id])
  end

  def build_payment_for_step(order, step)
    payment = order.payments.build(
      method: Payment.method_keys.first,
      amount: calculate_amount_for_step(order, step),
      gateway_reference: "step_#{step}"
    )
    payment
  end

  def calculate_amount_for_step(order, step)
    remaining = order.balance_due
    if remaining <= 0
      return 0.01 # Minimum payment to move past the step
    end

    max_per_step = remaining / (step - 1).to_f + 1.0 if step > 2
    [remaining, max_per_step].min rescue remaining
  end

  def record_payment(order_id, amount)
    order = Order.find(order_id)
    lifecycle = OrderLifecycle.new(order, current_user)
    payment = @payment.dup
    payment.amount = amount
    lifecycle.record_payment!(payment)
    update_order_status_after_payment(lifecycle)
  end

  def update_order_status_after_payment(lifecycle)
    paid_amount = order.payments.successful.sum(:amount)
    if paid_amount >= order.total
      order.update_columns(payment_status: :paid, status: :paid)
      # Broadcast to kitchen channel to wake up pending orders
      Turbo::StreamsChannel.broadcast_replace_to(
        OrderChannel.stream_name(order.business_id),
        target: "order-#{order.id}",
        partial: "orders/ticket",
        locals: { order: order }
      )
    elsif paid_amount > 0
      order.update_columns(payment_status: :partially_paid)
    end
  end
end
