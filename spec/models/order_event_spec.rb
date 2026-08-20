require "rails_helper"

RSpec.describe OrderEvent do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "immutability" do
    it "is readonly once persisted" do
      order = within_tenant { create(:order, business: business) }
      within_tenant { create(:order_event, order: order) }
      persisted = within_tenant { OrderEvent.find(order.order_events.first.id) }

      expect(persisted).to be_readonly

      expect { within_tenant { persisted.update!(event: "cancelled") } }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { within_tenant { persisted.destroy! } }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "validations" do
    it "requires an event name" do
      event = within_tenant { build(:order_event, event: nil) }

      expect(event).not_to be_valid
    end

    it "requires metadata" do
      event = within_tenant { build(:order_event, metadata: nil) }

      expect(event).not_to be_valid
    end

    it "stores arbitrary metadata as JSONB" do
      order = within_tenant { create(:order, business: business) }
      event = within_tenant do
        create(:order_event, order: order, event: "paid", metadata: { "amount" => "42.00", "method" => "pix" })
      end

      expect(event.metadata).to eq({ "amount" => "42.00", "method" => "pix" })
    end
  end

  describe "timeline" do
    it "records only a created_at timestamp" do
      order = within_tenant { create(:order, business: business) }
      event = within_tenant { create(:order_event, order: order) }

      expect(event.created_at).to be_present
      expect(event.respond_to?(:updated_at)).to be(false)
    end

    it "orders events by creation time within an order" do
      order = within_tenant { create(:order, business: business) }
      first = within_tenant { create(:order_event, order: order, event: "confirmed") }
      second = within_tenant { create(:order_event, order: order, event: "paid") }

      expect(order.order_events.order(:created_at).pluck(:event)).to eq(%w[confirmed paid])
      expect(order.order_events.pluck(:id)).to include(first.id, second.id)
    end
  end
end
