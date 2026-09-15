# An order is the root of a sale: line items with price snapshots, payments and
# an immutable event timeline. Status transitions are driven exclusively by
# OrderLifecycle so every move is validated and audited.

class OrderPaymentController < AuthenticatedController
  before_action :set_order

  def show
    authorize @order, :pay?

    current_step = payment_step(@order)
    @step = params[:step]&.to_i || current_step

    unless (@step..@step + 1).cover?(current_step)
      redirect_to checkout_path(@order), alert: t("orders.invalid_step")
    else
      @payment = build_payment_for_step(@order, @step)
    end
  end

  def create
    authorize @order, :pay?

    amount = (params.dig(:payment, :amount) || params[:amount]).to_f.round(2)
    method = params.dig(:payment, :method).presence || Payment.methods.keys.first

    if amount < 0
      redirect_to checkout_path(@order), alert: t("orders.negative_amount")
      return
    end

    if amount.zero?
      redirect_to checkout_path(@order), alert: t("orders.zero_amount")
      return
    end

    if amount > @order.balance_due
      redirect_to checkout_path(@order), alert: t("orders.exceeds_balance")
      return
    end

    authorization = payment_gateway(Current.business).authorize(
      settings: payment_settings(Current.business),
      amount: amount,
      order_id: @order.id,
      metadata: { source: "checkout", payment_method: method }
    )
    unless authorization[:success]
      redirect_to checkout_path(@order), alert: authorization[:message]
      return
    end

    lifecycle = OrderLifecycle.new(@order, current_user)
    payment = @order.payments.build(
      method: method,
      amount: amount,
      gateway_reference: authorization.dig(:metadata, :auth_token)
    )

    begin
      if authorization.dig(:metadata, :status).to_s == "pending"
        # Real gateway (e.g. Pix) confirms asynchronously; the status poller
        # flips the payment to succeeded once the provider reports approval.
        lifecycle.pending_payment!(payment)
        redirect_to checkout_path(@order), notice: t("orders.payment_pending")
        return
      end

      lifecycle.record_payment!(payment)
      if payment.status == :succeeded && @order.balance_due > 0 && @order.status == "open"
        @order.update_column(status: "partially_paid")
      end
      if @order.paid?
        redirect_to order_path(@order), notice: t("orders.paid")
      else
        redirect_to checkout_path(@order), notice: t("orders.partial_payment")
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to checkout_path(@order), alert: e.record.errors.full_messages.to_sentence
    rescue OrderLifecycle::IllegalTransition
      redirect_to checkout_path(@order), alert: t("orders.cannot_pay")
    end
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:order_id])
  end

  def payment_step(order)
    case order.payment_status.to_sym
    when :pending      then 1
    when :partially_paid then 2
    else 3
    end
  end

  # Returns the recommended amount to advance from current payment_status to next.
  # pending: 2 remaining statuses (partial + paid) → equal split
  # partially_paid: 1 remaining status → full remainder
  # Any status that implies a zero balance is handled by the early return above.
  def calculate_amount_for_step(order, step)
    remaining = order.balance_due
    return 0.01 if remaining <= 0

    remaining_statuses = case order.payment_status.to_sym
    when :pending then 2
    else 1
    end

    (remaining / remaining_statuses).round(2)
  end

  # Renders the checkout form without authorizing: showing the page must never
  # move money through the gateway. The amount/method here are suggestions that
  # the cashier confirms on submit (POST create performs the real authorize).
  def build_payment_for_step(order, step)
    amount = calculate_amount_for_step(order, step)

    order.payments.build(
      method: Payment.methods.keys.first,
      amount: amount,
      gateway_reference: nil
    )
  end

  # Resolves the payment adapter from the business's integration mode so the
  # same checkout switches between sandbox (mock) and real gateway live.
  def payment_gateway(business)
    AdapterResolver.resolve(business, :payment_gateway)
  end

  # The mock adapter reads :currency only; the real gateway needs the stored
  # sandbox credentials (MP access token etc.) so it is reached as-is.
  def payment_settings(business)
    AdapterResolver.settings_for(business, :payment_gateway).merge(currency: "BRL")
  end
end
