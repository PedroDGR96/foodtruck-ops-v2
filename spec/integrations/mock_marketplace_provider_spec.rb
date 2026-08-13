require "rails_helper"

RSpec.describe MockMarketplaceProvider, type: :model do
  describe ".create_order" do
    it "returns a success result with a deterministic order number" do
      result = described_class.create_order(
        settings: { merchant_id: 42, platform: "ifood" },
        args: { merchant_id: 42, platform: "ifood", user_id: "u1", items_count: 3, total_amount: 100.0 }
      )

      expect(result[:success]).to be true
      expect(result[:data][:order_num]).to be_an(Integer)
      expect(result[:data][:platform]).to eq("ifood")
      expect(result[:data][:status]).to eq("pending")
    end

    it "always derives the same order number for the same merchant/platform" do
      args = { merchant_id: 7, platform: "99food", total_amount: 100.0 }
      first = described_class.create_order(settings: {}, args: args)[:data][:order_num]
      second = described_class.create_order(settings: {}, args: args)[:data][:order_num]

      expect(first).to eq(second)
    end

    it "rejects a missing merchant id" do
      expect { described_class.create_order(settings: {}, args: { platform: "ifood" }) }
        .to raise_error(KeyError)
    end
  end

  describe ".update_order" do
    it "returns a success result with the new status" do
      result = described_class.update_order(
        settings: {}, args: { order_num: 1234, status: "confirmed" }
      )

      expect(result[:success]).to be true
      expect(result[:data][:status]).to eq("confirmed")
    end
  end

  describe ".cancel_order" do
    it "returns a success result with cancelled status" do
      result = described_class.cancel_order(
        settings: {}, args: { order_num: 1234, merchant_id: 42 }
      )

      expect(result[:success]).to be true
      expect(result[:data][:status]).to eq("cancelled")
    end

    it "rejects a missing order number" do
      expect { described_class.cancel_order(settings: {}, args: { merchant_id: 42 }) }
        .to raise_error(KeyError)
    end
  end
end
