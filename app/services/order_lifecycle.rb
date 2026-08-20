# Drives every order status transition. Transitions are validated against the
# pinned state machine, recorded on the immutable order_events timeline with
# the acting user, and broadcast to the business's order stream.
class OrderLifecycle
  class IllegalTransition < StandardError
    attr_reader :event, :from_status

    def initialize(event, from_status)
      @event = event
      @from_status = from_status
      super("Illegal transition #{event} from #{from_status}")
    end
  end

  attr_reader :order, :actor

  def initialize(order, actor)
    @order = order
    @actor = actor
  end

  def confirm!
    transition!("confirmed", %i[draft], :open)
  end

  def discard!
    transition!("discarded", %i[draft], :cancelled)
    broadcast_remove
  end

  def cancel!(force: false)
    if force
      cash_refunds = order.cash_payments_refundable
      transition!("cancelled", %i[paid in_kitchen ready partially_paid cancelled], :cancelled, { override: true })
      refund_payments!
      record_refund_movements!(cash_refunds)
      broadcast_remove
      broadcast_kds_remove
    else
      transition!("cancelled", %i[draft open], :cancelled)
    end
  end

  def refund!
    cash_refunds = order.cash_payments_refundable
    transition!("refunded", %i[paid partially_paid cancelled], :refunded)
    refund_payments!
    record_refund_movements!(cash_refunds)
    broadcast_remove
    broadcast_kds_remove
  end

  def start_cooking!
    transition!("cooking_started", %i[paid partially_paid], :in_kitchen, {}, { kitchen_status: :in_progress, started_at: Time.current }, broadcast: false)
    broadcast_kds_replace
  end

  def mark_ready!
    transition!("ready", %i[in_kitchen], :ready, {}, { kitchen_status: :done, finished_at: Time.current }, broadcast: false)
    broadcast_kds_remove
    broadcast_kds_completed
  end

  def complete!
    transition!("completed", %i[ready], :completed)
  end

  # Records a payment leg, recomputes payment_status and advances the order to
  # partially_paid/paid as soon as the accumulated amount reaches the total.
  # Cash payments are tied to the cashier's open shift so the drawer
  # reconciliation can count them.
  def record_payment!(payment)
    raise IllegalTransition.new("payment", order.status) unless order.status.in?(%w[open partially_paid])

    ActiveRecord::Base.transaction do
      payment.order = order
      payment.cash_register ||= CashRegister.open.find_by(user: actor) if payment.cash? && actor
      payment.save!

      # Lock the order to prevent concurrent modifications during payment processing.
      # Without this, two simultaneous payments could both read a stale `paid` sum and
      # update based on their own calculations, causing payment_status to diverge from actual paid_amount.
      order.lock!

      # Move the paid sum computation inside the transaction after saving the payment
      # so it reflects all concurrent modifications within this transaction.
      paid = order.payments.successful.sum(:amount)
      if paid >= order.total
        order.update_columns(payment_status: :paid)
        transition!("paid", %i[open partially_paid], :paid, { amount: payment.amount.to_s, method: payment.method })
        broadcast_kds_append
      elsif paid.positive?
        order.update_columns(payment_status: :partially_paid)
        transition!("partially_paid", %i[open partially_paid], :partially_paid, { amount: payment.amount.to_s, method: payment.method })
      else
        order.update_columns(payment_status: :pending)
      end
    end
  end

  private

  def transition!(event, from_states, to_status, metadata = {}, extra_columns = {}, broadcast: true)
    unless from_states.include?(order.status.to_sym)
      raise IllegalTransition.new(event, order.status)
    end

    order.update!(status: to_status, **extra_columns)
    record_event(event, metadata)
    broadcast_replace if broadcast
  end

  def refund_payments!
    order.payments.successful.update_all(status: :refunded)
    order.update_columns(payment_status: :refunded)
  end

  def record_refund_movements!(cash_refunds)
    return if cash_refunds.empty?

    CashRegisterLedger.record_refunds!(payments: cash_refunds, order: order, actor: actor)
  end

  def record_event(event, metadata)
    order.order_events.create!(event: event, user: actor, metadata: metadata)
  end

  def broadcast_replace
    Turbo::StreamsChannel.broadcast_replace_to(
      OrderChannel.stream_name(Current.business.id),
      target: ActionView::RecordIdentifier.dom_id(order),
      partial: "orders/ticket",
      locals: { order: order }
    )
  end

  def broadcast_remove
    Turbo::StreamsChannel.broadcast_remove_to(
      OrderChannel.stream_name(Current.business.id),
      target: ActionView::RecordIdentifier.dom_id(order)
    )
  end

  def broadcast_kds_append
    Turbo::StreamsChannel.broadcast_append_to(
      KitchenChannel.stream_name(Current.business.id),
      target: "kitchen-queue-#{order.order_type}",
      partial: "kitchen/ticket",
      locals: { order: order }
    )
  end

  def broadcast_kds_replace
    Turbo::StreamsChannel.broadcast_replace_to(
      KitchenChannel.stream_name(Current.business.id),
      target: ActionView::RecordIdentifier.dom_id(order),
      partial: "kitchen/ticket",
      locals: { order: order }
    )
  end

  def broadcast_kds_remove
    Turbo::StreamsChannel.broadcast_remove_to(
      KitchenChannel.stream_name(Current.business.id),
      target: ActionView::RecordIdentifier.dom_id(order)
    )
  end

  def broadcast_kds_completed
    Turbo::StreamsChannel.broadcast_prepend_to(
      KitchenChannel.stream_name(Current.business.id),
      target: "kitchen-completed",
      partial: "kitchen/completed_ticket",
      locals: { order: order }
    )
  end
end
