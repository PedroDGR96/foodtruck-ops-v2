require "rails_helper"

RSpec.describe IntegrationSetting, type: :model do
  let(:business) { create(:business, timezone: "America/Sao_Paulo") }

  describe "validations" do
    it "is valid with a known provider key and credentials" do
      setting = Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "messaging",
                                     credentials: { token: "abc" })
      end

      expect(setting).to be_valid
    end

    it "rejects an unknown provider key" do
      setting = nil
      Tenancy.with_business(business) do
        setting = build(:integration_setting, business: business, provider_key: "bogus")
        expect(setting).not_to be_valid
        expect(setting.errors[:provider_key]).to be_present
      end
    end

    it "rejects duplicate provider keys for the same business" do
      Tenancy.with_business(business) { create(:integration_setting, business: business, provider_key: "maps") }

      Tenancy.with_business(business) do
        dup = build(:integration_setting, business: business, provider_key: "maps")
        expect(dup).not_to be_valid
        expect(dup.errors[:provider_key]).to be_present
      end
    end

    it "allows the same provider key for a different business" do
      other = create(:business)
      Tenancy.with_business(business) { create(:integration_setting, business: business, provider_key: "fiscal") }
      other_setting = Tenancy.with_business(other) { create(:integration_setting, business: other, provider_key: "fiscal") }

      expect(other_setting).to be_persisted
    end
  end

  describe "credentials storage" do
    it "stores the value as plain JSONB" do
      Tenancy.with_business(business) do
        setting = create(:integration_setting, business: business,
                                  credentials: { api_key: "plaintext-secret" })

        raw = IntegrationSetting.find(setting.id).read_attribute_before_type_cast("credentials")
        expect(raw).to include("plaintext-secret")
        expect(setting.credentials).to eq("api_key" => "plaintext-secret")
      end
    end
  end

  describe "tenant scoping" do
    it "is scoped to its business" do
      setting = Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "payment_gateway")
      end

      Tenancy.with_business(business) do
        expect(IntegrationSetting.where(provider_key: "payment_gateway")).to include(setting)
      end
    end

    it "does not leak records from other businesses" do
      other = create(:business)
      Tenancy.with_business(other) do
        create(:integration_setting, business: other, provider_key: "payment_gateway")
      end

      Tenancy.with_business(business) do
        expect(IntegrationSetting.where(provider_key: "payment_gateway")).to be_empty
      end
    end
  end

  describe ".enabled" do
    it "returns only enabled settings" do
      Tenancy.with_business(business) { create(:integration_setting, business: business, provider_key: "maps") }
      disabled = Tenancy.with_business(business) do
        create(:integration_setting, business: business, provider_key: "fiscal", enabled: false)
      end

      enabled = Tenancy.with_business(business) { IntegrationSetting.enabled.to_a }

      expect(enabled).not_to include(disabled)
      expect(disabled.enabled).to be(false)
    end
  end
end
