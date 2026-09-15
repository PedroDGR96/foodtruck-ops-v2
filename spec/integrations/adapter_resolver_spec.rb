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
      expect(AdapterResolver.resolve(business, :payment_gateway)).to eq(IntegrationsKit::MercadoPagoGateway)
      expect(AdapterResolver.resolve(business, :fiscal)).to eq(IntegrationsKit::FocusNFeProvider)
      expect(AdapterResolver.resolve(business, :marketplace)).to eq(IntegrationsKit::IfoodMarketplaceProvider)
      expect(AdapterResolver.resolve(business, :messaging)).to eq(IntegrationsKit::TwilioMessagingProvider)
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

  describe ".live?" do
    it "is false by default" do
      expect(AdapterResolver.live?(business)).to be(false)
    end

    it "is true after switching to live" do
      business.update!(integration_adapter_mode: "live")
      expect(AdapterResolver.live?(business)).to be(true)
    end
  end

  describe "fail-loud resolution" do
    it "raises NoRealAdapterError in live mode when no real adapter is registered" do
      business.update!(integration_adapter_mode: "live")
      stub_const("AdapterResolver::ADAPTERS",
                 payment_gateway: { mock: MockPaymentGateway },
                 maps: { mock: MockMapsProvider, real: OsmMapsProvider },
                 fiscal: { mock: MockFiscalProvider, real: IntegrationsKit::FocusNFeProvider },
                 marketplace: { mock: MockMarketplaceProvider, real: IntegrationsKit::IfoodMarketplaceProvider },
                 messaging: { mock: MockMessagingProvider, real: IntegrationsKit::TwilioMessagingProvider })

      expect { AdapterResolver.resolve(business, :payment_gateway) }
        .to raise_error(NoRealAdapterError, /payment_gateway/)
    end
  end

  describe ".settings_for" do
    it "returns symbolized stored credentials for the provider" do
      Tenancy.with_business(business) do
        business.integration_settings.create!(provider_key: "payment_gateway", credentials: { access_token: "APP_T", "public_key" => "APP_P" }, enabled: true)
      end

      Tenancy.with_business(business) do
        expect(AdapterResolver.settings_for(business, :payment_gateway)).to eq(access_token: "APP_T", public_key: "APP_P")
      end
    end

    it "returns an empty hash when no setting is stored" do
      Tenancy.with_business(business) do
        expect(AdapterResolver.settings_for(business, :payment_gateway)).to eq({})
      end
    end
  end
end
