require "rails_helper"

RSpec.describe OrderLifecycle do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:owner) { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  def build_order(status = :draft, **attrs)
    within_tenant { create(:order, status, business: business, **attrs) }
  end

  # Builds a payable order the way the app does: create it open, cover the
  # total with a payment, then move it to the requested status.
  def payable_order(status, total:)
    order = build_order(:open, total: total, subtotal: total)
    within_tenant { create(:payment, order: order, amount: total) }
    within_tenant do
      order.update!(status: status, payment_status: :paid)
      order.update!(kitchen_status: :in_progress) if status == :in_kitchen
    end
    order
  end

  def lifecycle(order, actor = cashier)
    OrderLifecycle.new(order, actor)
  end

  describe "confirm!" do
    it "moves a draft to open and records an event" do
      order = build_order(:draft)

      expect { lifecycle(order).confirm! }.not_to raise_error

      expect(order).to be_open
      event = within_tenant { order.order_events.last }
      expect(event.event).to eq("confirmed")
      expect(event.user).to eq(cashier)
    end

    it "rejects confirming a non-draft order" do
      order = build_order(:open)

      expect { lifecycle(order).confirm! }.to raise_error(OrderLifecycle::IllegalTransition)
    end
  end

  describe "cancel!" do
    it "cancels an unpaid draft or open order" do
      [ :draft, :open ].each do |status|
        order = build_order(status)
        lifecycle(order).cancel!
        expect(order).to be_cancelled
      end
    end

    it "refuses to cancel an already prep order without force" do
      order = payable_order(:paid, total: 10.0)

      expect { lifecycle(order).cancel! }.to raise_error(OrderLifecycle::IllegalTransition)
    end

    it "cancels and refunds payments when forced" do
      order = payable_order(:in_kitchen, total: 10.0)

      lifecycle(order, owner).cancel!(force: true)

      expect(order).to be_cancelled
      expect(order.payment_status).to eq("refunded")
      expect(within_tenant { order.payments.refunded.size }).to eq(1)
    end
  end

  describe "discard!" do
    it "cancels a draft without refunding" do
      order = build_order(:draft)

      lifecycle(order).discard!

      expect(order).to be_cancelled
      expect(within_tenant { order.order_events.last.event }).to eq("discarded")
    end
  end

  describe "refund!" do
    it "refunds a paid order and marks its payments refunded" do
      order = payable_order(:paid, total: 25.0)

      lifecycle(order, owner).refund!

      expect(order).to be_refunded
      expect(order.payment_status).to eq("refunded")
      expect(within_tenant { order.payments.refunded.size }).to eq(1)
    end

    it "rejects refunding an order that never reached a payable state" do
      order = build_order(:open)

      expect { lifecycle(order).refund! }.to raise_error(OrderLifecycle::IllegalTransition)
    end
  end

  describe "kitchen transitions" do
    it "moves a paid order into the kitchen and starts it" do
      order = build_order(:paid)

      lifecycle(order).start_cooking!

      expect(order).to be_in_kitchen
      expect(order.kitchen_status).to eq("in_progress")
      expect(order.started_at).to be_within(2.seconds).of(Time.current)
    end

    it "marks a kitchen order as ready" do
      order = build_order(:in_kitchen)

      lifecycle(order).mark_ready!

      expect(order).to be_ready
      expect(order.kitchen_status).to eq("done")
      expect(order.finished_at).to be_within(2.seconds).of(Time.current)
    end

    it "completes a ready order" do
      order = build_order(:ready)

      lifecycle(order).complete!

      expect(order).to be_completed
    end
  end

  describe "record_payment!" do
    it "marks the order paid when the payment covers the total" do
      order = build_order(:open, total: 30.0, subtotal: 30.0)
      payment = order.payments.build(method: "pix", amount: 30.0)

      lifecycle(order).record_payment!(payment)

      expect(order).to be_paid
      expect(order.payment_status).to eq("paid")
      expect(within_tenant { order.order_events.last.event }).to eq("paid")
    end

    it "keeps the order partially paid until the balance is settled" do
      order = build_order(:open, total: 30.0, subtotal: 30.0)

      first = order.payments.build(method: "cash", amount: 10.0)
      lifecycle(order).record_payment!(first)

      expect(order).to be_partially_paid
      expect(order.payment_status).to eq("partially_paid")

      second = order.payments.build(method: "card", amount: 20.0)
      lifecycle(order).record_payment!(second)

      expect(order).to be_paid
      expect(within_tenant { order.payments.successful.sum(:amount) }).to eq(30.0)
    end

    it "rejects payments on a closed order" do
      order = build_order(:draft)
      payment = order.payments.build(method: "cash", amount: 5.0)

      expect { lifecycle(order).record_payment!(payment) }
        .to raise_error(OrderLifecycle::IllegalTransition)
    end

    it "persists the payment amount and method in the event metadata" do
      order = build_order(:open, total: 15.0, subtotal: 15.0)
      payment = order.payments.build(method: "card", amount: 15.0)

      lifecycle(order).record_payment!(payment)

      event = within_tenant { order.order_events.last }
      expect(event.metadata).to include("amount" => "15.0", "method" => "card")
    end
  end

  describe "audit timeline" do
    it "appends an event for every transition with the acting user" do
      order = build_order(:paid)

      lifecycle(order, owner).start_cooking!
      lifecycle(order, cashier).mark_ready!
      lifecycle(order, cashier).complete!

      events = within_tenant { order.order_events.order(:created_at).pluck(:event, :user_id) }

      expect(events).to eq([
        [ "cooking_started", owner.id ],
        [ "ready", cashier.id ],
        [ "completed", cashier.id ]
      ])
    end
  end

  describe "broadcasts" do
    it "broadcasts a ticket replacement on transitions" do
      order = build_order(:open)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with(OrderChannel.stream_name(business.id), hash_including(partial: "orders/ticket"))
        .and_call_original

      lifecycle(order).cancel!
    end

    it "broadcasts a removal for cancellations, discards and refunds" do
      order = payable_order(:in_kitchen, total: 10.0)

      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(OrderChannel.stream_name(business.id), anything)
        .and_call_original
      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(KitchenChannel.stream_name(business.id), anything)
        .and_call_original

      lifecycle(order, owner).cancel!(force: true)
    end

    it "appends a kitchen ticket when the order is paid" do
      order = build_order(:open, total: 30.0, subtotal: 30.0)
      payment = order.payments.build(method: "pix", amount: 30.0)

      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to)
        .with(KitchenChannel.stream_name(business.id), hash_including(target: "kitchen-queue-#{order.order_type}", partial: "kitchen/ticket"))
        .and_call_original

      lifecycle(order).record_payment!(payment)
    end

    it "replaces the kitchen ticket when cooking starts" do
      order = build_order(:paid)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with(KitchenChannel.stream_name(business.id), hash_including(partial: "kitchen/ticket"))
        .and_call_original

      lifecycle(order).start_cooking!
    end

    it "removes the ticket from the queue and prepends a completed ticket when ready" do
      order = build_order(:in_kitchen)

      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(KitchenChannel.stream_name(business.id), anything)
        .and_call_original
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        .with(KitchenChannel.stream_name(business.id), hash_including(target: "kitchen-completed", partial: "kitchen/completed_ticket"))
        .and_call_original

      lifecycle(order).mark_ready!
    end

    it "removes the kitchen ticket when a kitchen order is force-cancelled" do
      order = payable_order(:in_kitchen, total: 10.0)

      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(OrderChannel.stream_name(business.id), anything)
        .and_call_original
      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(KitchenChannel.stream_name(business.id), anything)
        .and_call_original

      lifecycle(order, owner).cancel!(force: true)
    end

    it "removes the kitchen ticket when a kitchen order is refunded" do
      order = payable_order(:paid, total: 10.0)

      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(OrderChannel.stream_name(business.id), anything)
        .and_call_original
      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
        .with(KitchenChannel.stream_name(business.id), anything)
        .and_call_original

      lifecycle(order, owner).refund!
    end
  end
end
