require "rails_helper"

RSpec.describe MockMessagingProvider, type: :model do
  describe ".send_whatsapp" do
    it "returns a success result with the phone" do
      result = described_class.send_whatsapp(settings: {}, phone: "5511999999999", message: "Hi")

      expect(result[:success]).to be true
      expect(result[:message]).to include("5511999999999")
    end

    it "rejects an empty message" do
      expect { described_class.send_whatsapp(settings: {}, phone: "55119", message: "  ") }
        .to raise_error(ArgumentError, /empty/i)
    end
  end

  describe ".send_sms" do
    it "returns success and a deterministic cost computed by segment count" do
      result = described_class.send_sms(settings: {}, phone: "55119", message: "x" * 160)

      expect(result[:success]).to be true
      expect(result[:cost]).to eq(0.05)
    end

    it "scales cost by the number of 160 char segments" do
      result = described_class.send_sms(settings: {}, phone: "55119", message: "x" * 161)

      expect(result[:success]).to be true
      expect(result[:cost]).to eq(0.10)
    end
  end

  describe ".send_email" do
    it "returns a success result" do
      result = described_class.send_email(settings: {}, email: "user@example.com", message: "Hi")

      expect(result[:success]).to be true
      expect(result[:message]).to include("user@example.com")
    end
  end

  describe ".bulk_send" do
    it "returns one result per message and preserves ordering" do
      messages = [
        { type: "whatsapp", to: "55119", body: "Hi" },
        { type: "email", to: "user@example.com", body: "Hi" }
      ]

      results = described_class.bulk_send(settings: {}, messages: messages)

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:success] }).to eq([ true, true ])
    end

    it "returns a failure for an unknown message type" do
      results = described_class.bulk_send(settings: {}, messages: [ { type: "carrier_pigeon", to: "x", body: "Hi" } ])

      expect(results.first[:success]).to be false
    end
  end
end
