require "rails_helper"

RSpec.describe IntegrationsHelper, type: :helper do
  describe "#provider_fields" do
    it "returns payment gateway fields" do
      fields = helper.provider_fields("payment_gateway")
      expect(fields.map { |f| f[:key] }).to include("public_key", "access_token", "sandbox")
    end

    it "returns messaging fields" do
      fields = helper.provider_fields("messaging")
      expect(fields.map { |f| f[:key] }).to include("twilio_account_sid", "twilio_auth_token")
    end

    it "returns maps fields" do
      fields = helper.provider_fields("maps")
      expect(fields.map { |f| f[:key] }).to include("provider", "api_key")
    end

    it "returns fiscal fields" do
      fields = helper.provider_fields("fiscal")
      expect(fields.map { |f| f[:key] }).to include("environment", "cnpj")
    end

    it "returns marketplace fields" do
      fields = helper.provider_fields("marketplace")
      expect(fields.map { |f| f[:key] }).to include("merchant_id", "platform")
    end

    it "returns empty array for unknown provider" do
      expect(helper.provider_fields("unknown")).to eq([])
    end

    it "marks password fields correctly" do
      fields = helper.provider_fields("payment_gateway")
      pw_fields = fields.select { |f| f[:type] == :password }
      expect(pw_fields.map { |f| f[:key] }).to include("access_token", "webhook_secret")
    end

    it "marks select fields correctly" do
      fields = helper.provider_fields("payment_gateway")
      select_fields = fields.select { |f| f[:type] == :select }
      expect(select_fields.map { |f| f[:key] }).to include("sandbox")
    end
  end
end
