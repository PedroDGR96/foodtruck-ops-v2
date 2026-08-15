# An order is the root of a sale: line items with price snapshots, payments and
# an immutable event timeline. Status transitions are driven exclusively by
# OrderLifecycle so every move is validated and audited.

class OrderPaymentController < AuthenticatedController
  before_action :set_order

  def show
    authorize @order, :pay?

    # Determine which payment step we're on based on current payment_status
    # Payment status: pending -> partially_paid -> paid
    # Each status transition corresponds to a "step" completed
    current_step = case @order.payment_status.to_sym
                  when :pending      then 1
                  when :partially_paid then 2
                  else 3 # Anything else (paid, refunded) is step 3+
                  end

    @step = params[:step]&.to_i || current_step

    unless [@step, @step + 1].cover?(current_step)
      redirect_to new_order_payment_path(@order), alert: "Invalid payment step"
    else
      @payment = build_payment_for_step(@order, @step)
    end
  end

  def create
    authorize @order, :pay?
    order = params[:order]
    amount = (params[:amount]&.to_f || 0).round(2)

    # Validate: negative amounts redirect to new form (render template)
    if amount < 0
      render action: 'new', alert: "Payment amount cannot be negative"
      return
    end

    # Handle zero amount: don't record payment, just validate
    if amount == 0
      render action: 'new', alert: "Amount must be greater than zero"
      return
    end

    # Positive amount - record the payment through lifecycle
    lifecycle = OrderLifecycle.new(@order, current_user)
    lifecycle.record_payment!(build_payment_for_step(@order, @step))

    redirect_to new_order_payment_path(order), notice: "Payment recorded"
  rescue ActiveRecord::RecordInvalid => e
    # Validation errors from Payment model - return to form with error messages
    render action: 'new', alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:order_id])
  end

  # Returns the minimum required payment to advance from current payment_status to next.
  # The incremental checkout flow: pending -> partially_paid -> paid (3 statuses total)
  # Each transition corresponds to one "step" of payment completion.
  def calculate_amount_for_step(order, step)
    remaining = order.balance_due

    # If fully paid (remaining <= 0), return minimal positive amount for validation
    return 0.01 if remaining <= 0

    # Determine how many steps remain until fully paid based on current payment_status:
    # pending: needs to go to partially_paid then paid → 2 more statuses = 2 steps needed
    # partially_paid: needs to go to paid → 1 more status = 1 step needed  
    # Anything else (paid, refunded): already done → no steps remain
    remaining_statuses = case order.payment_status.to_sym
                        when :pending      then 2
                        when :partially_paid then 1
                        else 0
                        end

    return remaining if remaining_statuses == 0 || remaining < 0.01

    # Calculate equal split across remaining statuses (e.g., $100 over 2 steps = $50 each)
    amount_per_remaining = (remaining / remaining_statuses).round(2)
    [amount_per_remaining, remaining].min
  end

  def update_order_status_after_payment(lifecycle)
    return unless lifecycle && lifecycle.respond_to?(:order)

    paid_amount = lifecycle.order.payments.successful.sum(:amount)
    total = lifecycle.order.total

    if paid_amount >= total && !lifecycle.order.payment_status.in?([:paid, :refunded])
      # Fully paid - advance to paid status and broadcast
      lifecycle.order.update_columns(payment_status: :paid, status: :paid)
      Turbo::StreamsChannel.broadcast_replace_to(
        OrderChannel.stream_name(lifecycle.order.business_id),
        target: "order-#{lifecycle.order.id}",
        partial: "orders/ticket",
        locals: { order: lifecycle.order }
      )
    elsif paid_amount > 0 && !lifecycle.order.payment_status.in?([:pending, :partially_paid])
      # Already has payment but wasn't tracked - correct to partially_paid
      lifecycle.order.update_columns(payment_status: :partially_paid)
    end
  end

  def record_payment(order_id, amount)
    order = Order.find(order_id)
    lifecycle = OrderLifecycle.new(order, current_user)
    payment = build_payment_for_step(order, @step)
    payment.amount = amount.round(2)
    lifecycle.record_payment!(payment)
    update_order_status_after_payment(lifecycle)
  end

  def build_payment_for_step(order, step)
    payment = order.payments.build(
      method: Payment.method_keys.first,
      amount: calculate_amount_for_step(order, step),
      gateway_reference: "step_#{step}"
    )
    payment
  end
end
