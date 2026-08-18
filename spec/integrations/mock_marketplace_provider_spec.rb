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

    it "defaults platform to ifood" do
      result = described_class.create_order(
        settings: {},
        args: { merchant_id: 1, total_amount: 50.0 }
      )

      expect(result[:data][:platform]).to eq("ifood")
    end

    it "generates a code starting with IFO" do
      result = described_class.create_order(
        settings: {},
        args: { merchant_id: 1, total_amount: 50.0 }
      )

      expect(result[:data][:code]).to start_with("IFO-")
    end

    it "includes default customer_name and items_count" do
      result = described_class.create_order(
        settings: {},
        args: { merchant_id: 1, total_amount: 50.0 }
      )

      expect(result[:data][:customer_name]).to start_with("Cliente")
      expect(result[:data][:items_count]).to eq(1)
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

    it "defaults status to confirmed" do
      result = described_class.update_order(
        settings: {}, args: { order_num: 1234 }
      )

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

    it "rejects a missing merchant_id" do
      expect { described_class.cancel_order(settings: {}, args: { order_num: 1234 }) }
        .to raise_error(KeyError)
    end

    it "uses default cancel reason" do
      result = described_class.cancel_order(
        settings: {}, args: { order_num: 1234, merchant_id: 42 }
      )

      expect(result[:data][:cancel_reason]).to eq("Cancelamento solicitado")
    end

    it "includes platform in message" do
      result = described_class.cancel_order(
        settings: {}, args: { order_num: 1234, merchant_id: 42, platform: "99food" }
      )

      expect(result[:message]).to include("99food")
    end
  end

  describe ".status" do
    it "returns the status for an order" do
      result = described_class.status(
        settings: {}, args: { order_num: 1234 }
      )

      expect(result[:success]).to be true
      expect(result[:data][:order_num]).to eq(1234)
      expect(result[:data][:status]).to eq("pending")
    end

    it "uses provided status" do
      result = described_class.status(
        settings: {}, args: { order_num: 1234, status: "delivered" }
      )

      expect(result[:data][:status]).to eq("delivered")
    end
  end

  describe ".webhook_verify" do
    it "verifies matching token" do
      result = described_class.webhook_verify(
        settings: { webhook_token: "secret123" },
        args: { x_ifood_signature: "secret123" }
      )

      expect(result[:success]).to be true
    end

    it "rejects mismatched token" do
      result = described_class.webhook_verify(
        settings: { webhook_token: "secret123" },
        args: { x_ifood_signature: "wrong" }
      )

      expect(result[:success]).to be false
    end

    it "rejects when no token configured" do
      result = described_class.webhook_verify(
        settings: {},
        args: { x_ifood_signature: "anything" }
      )

      expect(result[:success]).to be false
      expect(result[:message]).to include("Token")
    end
  end
end
