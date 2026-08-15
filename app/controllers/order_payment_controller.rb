# An order is the root of a sale: line items with price snapshots, payments and
# an immutable event timeline. Status transitions are driven exclusively by
# OrderLifecycle so every move is validated and audited.

class OrderPaymentController < AuthenticatedController
  before_action :set_order

  def show
    authorize @order, :pay?

    current_step = case @order.payment_status.to_sym
    when :pending      then 1
    when :partially_paid then 2
    else 3
    end

    @step = params[:step]&.to_i || current_step

    unless (@step..@step + 1).cover?(current_step)
      redirect_to checkout_path(@order), alert: "Invalid payment step"
    else
      @payment = build_payment_for_step(@order, @step)
    end
  end

  def create
    authorize @order, :pay?

    amount = params.dig(:payment, :amount) || params[:amount]
    amount = amount.to_f.round(2) rescue 0

    current_step = case @order.payment_status.to_sym
    when :pending      then 1
    when :partially_paid then 2
    else 3
    end
    @step = params[:step]&.to_i || current_step

    if amount < 0
      redirect_to checkout_path(@order), alert: "Payment amount cannot be negative"
      return
    end

    if amount == 0
      redirect_to checkout_path(@order), alert: "Amount must be greater than zero"
      return
    end

    lifecycle = OrderLifecycle.new(@order, current_user)
    payment = @order.payments.build(
      method: Payment.methods.keys.first,
      amount: amount,
      gateway_reference: "step_#{@step}"
    )

    begin
      lifecycle.record_payment!(payment)
      redirect_to checkout_path(@order), notice: "Payment recorded"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to checkout_path(@order), alert: e.record.errors.full_messages.to_sentence
    rescue OrderLifecycle::IllegalTransition
      redirect_to checkout_path(@order), alert: "This order cannot be paid"
    end
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:order_id])
  end

  # Returns the recommended amount to advance from current payment_status to next.
  # pending: 2 remaining statuses (partial + paid) → equal split
  # partially_paid: 1 remaining status → full remainder
  def calculate_amount_for_step(order, step)
    remaining = order.balance_due
    return 0.01 if remaining <= 0

    remaining_statuses = case order.payment_status.to_sym
    when :pending      then 2
    when :partially_paid then 1
    else 0
    end

    return remaining if remaining_statuses == 0 || remaining < 0.01

    amount_per_remaining = (remaining / remaining_statuses).round(2)
    [ amount_per_remaining, remaining ].min
  end

  def build_payment_for_step(order, step)
    order.payments.build(
      method: Payment.methods.keys.first,
      amount: calculate_amount_for_step(order, step),
      gateway_reference: "step_#{step}"
    )
  end
end
