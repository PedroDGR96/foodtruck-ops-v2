require "rails_helper"

RSpec.describe MockPaymentGateway, type: :model do
  let(:order_id) { "order-123" }
  let(:amount) { 99.90 }

  describe ".authorize" do
    it "returns a success result with a deterministic auth token" do
      result = described_class.authorize(settings: { currency: "BRL" },
                                          amount: amount, order_id: order_id,
                                          metadata: { source: "pos_system" })

      expect(result[:success]).to be true
      expect(result[:metadata][:auth_token]).to eq("mock_auth_order-123")
      expect(result[:metadata][:amount]).to eq(99.9)
    end
  end

  describe ".capture" do
    it "succeeds with the matching auth token" do
      result = described_class.capture(settings: {}, order_id: order_id,
                                       auth_token: "mock_auth_order-123")

      expect(result).to eq(success: true,
                           message: "Payment captured for order order-123",
                           metadata: { order_id: "order-123", captured: true })
    end

    it "fails when the auth token does not match" do
      result = described_class.capture(settings: {}, order_id: order_id, auth_token: "bogus")

      expect(result[:success]).to be false
      expect(result[:message]).to include("Invalid authorization token")
    end
  end

  describe ".refund" do
    it "returns a success refund result" do
      result = described_class.refund(settings: {}, amount: amount, order_id: order_id)

      expect(result[:success]).to be true
      expect(result[:metadata][:amount]).to eq(99.9)
    end
  end

  describe ".status" do
    it "returns payment status data" do
      result = described_class.status(settings: {}, order_id: order_id)

      expect(result[:success]).to be true
      expect(result[:data][:state]).to eq("paid")
    end
  end
end
