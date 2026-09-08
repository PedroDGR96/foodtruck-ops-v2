require "rails_helper"

RSpec.describe AdapterResolver, type: :integration do
  let(:business) { create(:business) }

  describe ".resolve" do
    it "returns the mock adapter when the business is in mock mode" do
      expect(AdapterResolver.resolve(business, :payment_gateway)).to eq(MockPaymentGateway)
      expect(AdapterResolver.resolve(business, :maps)).to eq(MockMapsProvider)
    end

    it "returns the real adapter when live mode and a real adapter is registered" do
      business.update!(integration_adapter_mode: "live")
      expect(AdapterResolver.resolve(business, :maps)).to eq(OsmMapsProvider)
    end

    it "falls back to the mock when live mode but no real adapter is registered" do
      business.update!(integration_adapter_mode: "live")
      expect(AdapterResolver.resolve(business, :payment_gateway)).to eq(MockPaymentGateway)
    end

    it "raises for an unknown provider key" do
      expect { AdapterResolver.resolve(business, :teleport) }.to raise_error(KeyError)
    end
  end

  describe ".live?" do
    it "is false by default" do
      expect(AdapterResolver.live?(business)).to be(false)
    end

    it "is true after switching to live" do
      business.update!(integration_adapter_mode: "live")
      expect(AdapterResolver.live?(business)).to be(true)
    end
  end

  describe ".fallback?" do
    it "is false in mock mode regardless of the provider" do
      expect(AdapterResolver.fallback?(business, :payment_gateway)).to be(false)
      expect(AdapterResolver.fallback?(business, :maps)).to be(false)
    end

    it "is true for a provider without a real adapter in live mode" do
      business.update!(integration_adapter_mode: "live")
      expect(AdapterResolver.fallback?(business, :payment_gateway)).to be(true)
      expect(AdapterResolver.fallback?(business, :fiscal)).to be(true)
      expect(AdapterResolver.fallback?(business, :marketplace)).to be(true)
      expect(AdapterResolver.fallback?(business, :messaging)).to be(true)
    end

    it "is false for a provider with a real adapter in live mode" do
      business.update!(integration_adapter_mode: "live")
      expect(AdapterResolver.fallback?(business, :maps)).to be(false)
    end
  end
end
