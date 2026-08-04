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
      transition!("cancelled", %i[paid in_kitchen ready], :cancelled, override: true)
      refund_payments!
      broadcast_remove
    else
      transition!("cancelled", %i[draft open], :cancelled)
    end
  end

  def refund!
    transition!("refunded", %i[paid partially_paid cancelled], :refunded)
    refund_payments!
    broadcast_remove
  end

  def start_cooking!
    transition!("cooking_started", %i[paid], :in_kitchen, {}, kitchen_status: :in_progress)
  end

  def mark_ready!
    transition!("ready", %i[in_kitchen], :ready, {}, kitchen_status: :done)
  end

  def complete!
    transition!("completed", %i[ready], :completed)
  end

  # Records a payment leg, recomputes payment_status and advances the order to
  # partially_paid/paid as soon as the accumulated amount reaches the total.
  def record_payment!(payment)
    raise IllegalTransition.new("payment", order.status) unless order.status.in?(%w[open partially_paid])

    payment.order = order
    payment.save!

    paid = order.payments.successful.sum(:amount)
    if paid >= order.total
      order.update_columns(payment_status: :paid)
      transition!("paid", %i[open partially_paid], :paid, amount: payment.amount.to_s, method: payment.method)
    elsif paid.positive?
      order.update_columns(payment_status: :partially_paid)
      transition!("partially_paid", %i[open partially_paid], :partially_paid, amount: payment.amount.to_s, method: payment.method)
    else
      order.update_columns(payment_status: :pending)
    end
  end

  private

  def transition!(event, from_states, to_status, metadata = {}, extra_columns = {})
    unless from_states.include?(order.status.to_sym)
      raise IllegalTransition.new(event, order.status)
    end

    order.update!(status: to_status, **extra_columns)
    record_event(event, metadata)
    broadcast_replace
  end

  def refund_payments!
    order.payments.successful.update_all(status: :refunded)
    order.update_columns(payment_status: :refunded)
  end

  def record_event(event, metadata)
    order.order_events.create!(event: event, user: actor, metadata: metadata)
  end

  def broadcast_replace
    Turbo::StreamsChannel.broadcast_replace_to(
      OrderChannel.stream_name(order.business_id),
      target: ActionView::RecordIdentifier.dom_id(order),
      partial: "orders/ticket",
      locals: { order: order }
    )
  end

  def broadcast_remove
    Turbo::StreamsChannel.broadcast_remove_to(
      OrderChannel.stream_name(order.business_id),
      target: ActionView::RecordIdentifier.dom_id(order)
    )
  end
end
