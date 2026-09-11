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

  describe "record_payment!" do
    it "rejects a payment on an already paid order and writes no event" do
      order = build_paid_order(total: 20.0)
      events_before = within_tenant { order.order_events.to_a.size }
      payment = within_tenant { order.payments.build(method: "cash", amount: 10.0) }

      expect { lifecycle(order).record_payment!(payment) }
        .to raise_error(OrderLifecycle::IllegalTransition, /payment/)

      events_after = within_tenant { order.order_events.to_a.size }
      expect(events_after).to eq(events_before)
    end
  end

  private

  def build_paid_order(total:)
    within_tenant do
      create(:order, :paid, business: business, total: total, subtotal: total)
    end
  end

  def lifecycle(order, actor = cashier)
    OrderLifecycle.new(order, actor)
  end
end
