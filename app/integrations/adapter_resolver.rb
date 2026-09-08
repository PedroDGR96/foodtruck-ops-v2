# Resolves the concrete adapter class for a provider under a business's
# integration_adapter_mode ("mock" default vs "live"). Live mode prefers the
# real adapter; when none is registered yet it falls back to the mock so the
# demo flow never breaks mid-switch. The resolver owns the provider→class map,
# so controllers/services never hardcode a provider name.

class AdapterResolver
  # provider_key => { mock:, real:, backup: }
  ADAPTERS = {
    payment_gateway: { mock: MockPaymentGateway, real: nil, backup: MockPaymentGateway },
    maps: { mock: MockMapsProvider, real: OsmMapsProvider },
    fiscal: { mock: MockFiscalProvider, real: nil },
    marketplace: { mock: MockMarketplaceProvider, real: nil },
    messaging: { mock: MockMessagingProvider, real: nil }
  }.freeze

  class << self
    def resolve(business, provider_key)
      adapter_spec(provider_key).then do |spec|
        if live?(business) && spec[:real]
          spec[:real]
        else
          spec[:mock]
        end
      end
    end

    def live?(business)
      business.integration_adapter_mode == "live"
    end

    # True when live mode would fall back to the mock because no real adapter
    # is registered for the provider. Used to badge the UI as a fallback.
    def fallback?(business, provider_key)
      live?(business) && adapter_spec(provider_key)[:real].nil?
    end

    private

    def adapter_spec(provider_key)
      ADAPTERS.fetch(provider_key.to_sym)
    end
  end
end
