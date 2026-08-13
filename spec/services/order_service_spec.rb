require "rails_helper"

RSpec.describe OrderService, type: :service do
  let(:payment_gateway) { MockPaymentGateway }
  let(:marketplace) { MockMarketplaceProvider }
  let(:order_details) { { merchant_id: 42, platform: "ifood", total_amount: 100.0 } }

  subject(:service) { described_class.new(payment_gateway: payment_gateway, marketplace_provider: marketplace) }

  describe "#process_pos_payment" do
    it "drives the full authorize -> capture flow and marks paid" do
      result = service.process_pos_payment(
        order_details: order_details, payment_method: "pix", amount: 100.0, order_id: "ord-1"
      )

      expect(result[:success]).to be true
      expect(result[:payment_status]).to eq("paid")
      expect(result[:order_num]).to be_an(Integer)
    end

    it "is deterministic: same inputs yield the same order number" do
      first = service.process_pos_payment(order_details: order_details, payment_method: "pix", amount: 100.0, order_id: "ord-1")
      second = service.process_pos_payment(order_details: order_details, payment_method: "pix", amount: 100.0, order_id: "ord-1")

      expect(first[:order_num]).to eq(second[:order_num])
    end

    it "refunds when capture fails" do
      allow(payment_gateway).to receive(:capture).and_return(success: false, message: "capture failed")
      allow(payment_gateway).to receive(:refund).and_return(success: true, message: "refunded", metadata: {})

      result = service.process_pos_payment(
        order_details: order_details, payment_method: "pix", amount: 100.0, order_id: "ord-1"
      )

      expect(result[:success]).to be false
      expect(result[:message]).to include("Refund initiated")
      expect(result[:order_num]).to be_an(Integer)
    end

    it "returns failure immediately when marketplace order creation fails" do
      allow(marketplace).to receive(:create_order).and_return(success: false, message: "no capacity")

      result = service.process_pos_payment(
        order_details: order_details, payment_method: "pix", amount: 100.0, order_id: "ord-1"
      )

      expect(result[:success]).to be false
      expect(result[:message]).to include("Failed to create marketplace order")
    end

    it "returns a failure hash on an unexpected error" do
      allow(marketplace).to receive(:create_order).and_raise(StandardError, "boom")

      result = service.process_pos_payment(
        order_details: order_details, payment_method: "pix", amount: 100.0, order_id: "ord-1"
      )

      expect(result[:success]).to be false
      expect(result[:message]).to include("Critical error")
      expect(result[:details]).to include("boom")
    end
  end
end
