# Ingests real iFood marketplace events via long-polling and acknowledges them,
# keeping a durable audit trail per received event. Runs only for businesses
# with the marketplace provider in live mode and credentials configured.
#
# Order creation from a PLACED event maps the provider payload onto the POS
# domain; that mapping is validated against real test-store payloads during the
# manual iFood onboarding. Until then, events are fetched, acknowledged and
# audited so the integration is exercised end-to-end without dropping data.
class MarketplaceEventPoller < ApplicationJob
  queue_as :default

  PLACED_EVENT = "PLACED".freeze

  def perform
    Business.where(integration_adapter_mode: "live").find_each do |business|
      Tenancy.with_business(business) do
        settings = AdapterResolver.settings_for(Current.business, :marketplace)
        next if settings[:client_id].blank? || settings[:client_secret].blank?

        events = poll_events(settings)
        next if events.empty?

        acknowledge(settings, events)
        ingest(events)
      end
    end
  end

  private

  def poll_events(settings)
    result = provider.poll_events(settings: settings, args: {})
    return [] unless result[:success]

    Array(result.dig(:data, :events))
  rescue StandardError => e
    Rails.logger.warn "[MarketplaceEventPoller] poll falhou: #{e.message}"
    []
  end

  def acknowledge(settings, events)
    result = provider.acknowledge_events(settings: settings, args: { events: events })
    unless result[:success]
      Rails.logger.error "[MarketplaceEventPoller] acknowledge falhou: #{result[:message]}"
    end
  end

  def ingest(events)
    events.each do |event|
      AuditLog.record!(
        action: "marketplace_event",
        resource: "marketplace",
        resource_id: event["orderId"].to_s,
        metadata: { event: event }
      )
      Rails.logger.info "[MarketplaceEventPoller] evento #{event["code"]} pedido #{event["orderId"]}"
    end
  end

  def provider
    AdapterResolver.resolve(Current.business, :marketplace)
  end
end
