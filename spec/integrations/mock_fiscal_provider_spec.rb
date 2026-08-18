require "rails_helper"

RSpec.describe MockFiscalProvider, type: :model do
  describe ".emit_nfc_e" do
    it "emits an NFC-e and assigns a deterministic number" do
      result = described_class.emit_nfc_e(
        settings: {},
        args: { order_id: "ord-1", payment_method: "pix", total_amount: 100.0 }
      )

      expect(result[:success]).to be true
      expect(result[:data][:nfc_e_number]).to eq("NFCe-ord-1")
      expect(result[:data][:total_amount]).to eq(100.0)
    end

    it "uses the supplied number when provided" do
      result = described_class.emit_nfc_e(
        settings: {},
        args: { order_id: "ord-1", payment_method: "pix", total_amount: 50.0, nfc_e_number: "NFCe-9999" }
      )

      expect(result[:data][:nfc_e_number]).to eq("NFCe-9999")
    end
  end

  describe ".emit_nf_e" do
    it "emits an NF-e with a deterministic number" do
      result = described_class.emit_nf_e(
        settings: {},
        args: { order_id: "ord-2", payment_method: "card", total_amount: 250.0 }
      )

      expect(result[:success]).to be true
      expect(result[:data][:nf_e_number]).to eq("NFe-ord-2")
    end

    it "uses the supplied number when provided" do
      result = described_class.emit_nf_e(
        settings: {},
        args: { order_id: "ord-2", payment_method: "card", total_amount: 250.0, nf_e_number: "NFe-8888" }
      )

      expect(result[:data][:nf_e_number]).to eq("NFe-8888")
    end
  end

  describe ".status" do
    it "returns authorized status for a document" do
      result = described_class.status(
        settings: {},
        args: { access_key: "35210112345678000190550010000001231234567890" }
      )

      expect(result[:success]).to be true
      expect(result[:data][:status]).to eq("authorized")
      expect(result[:data][:access_key]).to eq("35210112345678000190550010000001231234567890")
    end
  end

  describe ".cancel" do
    it "returns cancelled status for a document" do
      result = described_class.cancel(
        settings: {},
        args: { access_key: "35210112345678000190550010000001231234567890" }
      )

      expect(result[:success]).to be true
      expect(result[:data][:status]).to eq("cancelled")
      expect(result[:data][:access_key]).to eq("35210112345678000190550010000001231234567890")
    end
  end
end
