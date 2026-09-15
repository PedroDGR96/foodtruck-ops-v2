# Resolves the concrete adapter class for a provider under a business's
# integration_adapter_mode ("mock" default vs "live"). Live mode prefers the
# real adapter; the resolver owns the provider→class map, so controllers and
# services never hardcode a provider name. Real adapters are shipped by the
# integrations-kit gem and referenced here.
#
# Runtime behavior follows the agreed fail-loud contract: live mode never
# silently falls back to a mock adapter at runtime — it raises
# NoRealAdapterError instead.

class NoRealAdapterError < StandardError; end

class AdapterResolver
  # provider_key => { mock:, real: }
  ADAPTERS = {
    payment_gateway: { mock: MockPaymentGateway, real: IntegrationsKit::MercadoPagoGateway },
    maps:           { mock: MockMapsProvider, real: OsmMapsProvider },
    fiscal:         { mock: MockFiscalProvider, real: IntegrationsKit::FocusNFeProvider },
    marketplace:    { mock: MockMarketplaceProvider, real: IntegrationsKit::IfoodMarketplaceProvider },
    messaging:      { mock: MockMessagingProvider, real: IntegrationsKit::TwilioMessagingProvider }
  }.freeze

  class << self
    def resolve(business, provider_key)
      return providers(provider_key)[:mock] unless live?(business)

      real = providers(provider_key)[:real]
      raise NoRealAdapterError, "sem adapter real para #{provider_key} em modo live" if real.nil?

      real
    end

    def live?(business)
      business.integration_adapter_mode == "live"
    end

    # Symbolized credentials stored for the provider under the business, so
    # callers never reach into IntegrationSetting directly. Materializes
    # inside the caller's tenant block (RLS-safe).
    def settings_for(business, provider_key)
      setting = business.integration_settings.find_by(provider_key: provider_key.to_s)
      setting ? setting.credentials.deep_symbolize_keys : {}
    end

    private

    def providers(provider_key)
      ADAPTERS.fetch(provider_key.to_sym)
    end
  end
end
