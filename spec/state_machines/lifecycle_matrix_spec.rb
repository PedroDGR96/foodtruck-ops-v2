require "rails_helper"

RSpec.describe OrderLifecycle do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  let(:cashier) { Tenancy.with_business(business) { create(:user, :cashier, business: business) } }
  let(:owner)   { Tenancy.with_business(business) { create(:user, :owner, business: business) } }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  def build_order(status = :draft, **attrs)
    within_tenant { create(:order, status, business: business, **attrs) }
  end

  # Drives the order to the requested payable status the way the app does:
  # create it open, cover the total with a payment, then move it along.
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

  # The single source of truth for what each transition may legally do. Every
  # cell is validated against app/verticals/foodtruck/services/order_lifecycle.rb.
  LEGAL = {
    confirm!:       { draft: :open },
    discard!:       { draft: :cancelled },
    cancel!:        { draft: :cancelled, open: :cancelled },
    cancel_force!:  { paid: :cancelled, partially_paid: :cancelled, in_kitchen: :cancelled, ready: :cancelled, cancelled: :cancelled },
    refund!:        { paid: :refunded, partially_paid: :refunded, cancelled: :refunded },
    start_cooking!: { paid: :in_kitchen, partially_paid: :in_kitchen },
    mark_ready!:    { in_kitchen: :ready },
    complete!:      { ready: :completed }
  }.freeze

  STATUSES = %i[draft open partially_paid paid in_kitchen ready completed cancelled refunded].freeze

  describe "state transition matrix" do
    def props_for(status)
      case status
      when :open then { total: 30.0, subtotal: 30.0 }
      when :partially_paid then { total: 30.0, subtotal: 30.0 }
      when :paid, :in_kitchen, :ready then { total: 10.0, subtotal: 10.0 }
      when :completed, :cancelled, :refunded then {}
      else {}
      end
    end

    def order_for(status)
      case status
      when :paid, :in_kitchen, :ready
        payable_order(status, total: props_for(status)[:total])
      when :completed
        order = payable_order(:ready, total: 10.0)
        within_tenant { order.update!(kitchen_status: :done) }
        lifecycle(order, cashier).complete!
        order
      else
        build_order(status, **props_for(status))
      end
    end

    LEGAL.each do |action, map|
      describe action.to_s do
        STATUSES.each do |status|
          to = map[status]
          if to
            it "moves #{status} -> #{to}" do
              order = order_for(status)
              actor = action == :cancel_force! ? owner : cashier

              events = within_tenant { order.order_events.count }
              result = nil
              if action == :cancel_force!
                lifecycle(order, actor).cancel!(force: true)
                result = order.reload
              else
                lifecycle(order, actor).public_send(action)
                result = order.reload
              end

              expect(result.status).to eq(to.to_s)
              expect(within_tenant { order.order_events.count }).to eq(events + 1)
            end
          else
            it "rejects #{action} from #{status} without writing an event" do
              order = order_for(status)
              action_for_call = action == :cancel_force! ? :cancel! : action

              events = within_tenant { order.order_events.count }
              expect do
                if action == :cancel_force!
                  lifecycle(order, owner).cancel!(force: true)
                else
                  lifecycle(order, cashier).public_send(action_for_call)
                end
              end.to raise_error(OrderLifecycle::IllegalTransition)
              expect(within_tenant { order.order_events.count }).to eq(events)
            end
          end
        end
      end
    end

    describe "record_payment! payment legs" do
      it "records a full payment on an open order and lands on paid" do
        order = build_order(:open, total: 30.0, subtotal: 30.0)
        payment = within_tenant { order.payments.build(method: "pix", amount: 30.0) }

        events = within_tenant { order.order_events.count }
        lifecycle(order).record_payment!(payment)

        expect(order.reload).to be_paid
        expect(order.payment_status).to eq("paid")
        expect(within_tenant { order.order_events.count }).to eq(events + 1)
      end

      it "keeps an open order partially_paid on a partial payment" do
        order = build_order(:open, total: 30.0, subtotal: 30.0)
        payment = within_tenant { order.payments.build(method: "cash", amount: 10.0) }

        lifecycle(order).record_payment!(payment)

        expect(order.reload).to be_partially_paid
        expect(order.payment_status).to eq("partially_paid")
      end

      it "settles a partially_paid order once the balance is covered" do
        order = build_order(:open, total: 30.0, subtotal: 30.0)
        first = within_tenant { order.payments.build(method: "cash", amount: 10.0) }
        lifecycle(order).record_payment!(first)

        second = within_tenant { order.payments.build(method: "card", amount: 20.0) }
        lifecycle(order).record_payment!(second)

        expect(order.reload).to be_paid
        expect(order.payment_status).to eq("paid")
      end

      %i[draft paid in_kitchen ready completed cancelled refunded].each do |status|
        it "rejects a payment on a #{status} order without writing an event" do
          order = order_for(status)
          amount = status.in?(%i[paid in_kitchen]) ? 5.0 : 10.0
          payment = within_tenant { order.payments.build(method: "cash", amount: amount) }

          events = within_tenant { order.order_events.count }
          expect { lifecycle(order).record_payment!(payment) }
            .to raise_error(OrderLifecycle::IllegalTransition)
          expect(within_tenant { order.order_events.count }).to eq(events)
        end
      end
    end
  end
end
