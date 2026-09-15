require "rails_helper"

RSpec.describe MarketplaceEventPoller do
  let(:business) { create(:business, integration_adapter_mode: "live") }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  def marketplace_settings!(credentials: { client_id: "cid", client_secret: "csec" })
    within_tenant do
      create(:integration_setting, business: business, provider_key: "marketplace", credentials: credentials, enabled: true)
    end
  end

  it "polls, acknowledges and audits marketplace events" do
    marketplace_settings!

    events = [ { "eventId" => "EV1", "code" => "PLACED", "orderId" => "ORD-1" } ]
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:poll_events)
      .and_return(IntegrationsKit::Result.success(message: "eventos consultados", data: { events: events }))
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:acknowledge_events)
      .and_return(IntegrationsKit::Result.success(message: "eventos confirmados", metadata: { event_ids: [ "EV1" ] }))

    described_class.perform_now

    expect(IntegrationsKit::IfoodMarketplaceProvider).to have_received(:acknowledge_events).with(hash_including(args: { events: events }))
    audits = within_tenant { AuditLog.where(action: "marketplace_event").to_a }
    expect(audits.size).to eq(1)
    expect(audits.first.metadata["event"]["eventId"]).to eq("EV1")
  end

  it "recovers gracefully when polling fails" do
    marketplace_settings!

    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:poll_events).and_raise(StandardError, "boom")

    described_class.perform_now

    expect(IntegrationsKit::IfoodMarketplaceProvider).not_to receive(:acknowledge_events)
  end

  it "does not acknowledge or audit when the poll reports a failure" do
    marketplace_settings!
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:poll_events).and_return(
      IntegrationsKit::Result.failure(message: "iFood: HTTP 500")
    )

    described_class.perform_now

    expect(IntegrationsKit::IfoodMarketplaceProvider).not_to receive(:acknowledge_events)
    expect(within_tenant { AuditLog.where(action: "marketplace_event").count }).to eq(0)
  end

  it "warns but keeps ingesting when acknowledging fails" do
    marketplace_settings!
    events = [ { "eventId" => "EV1", "code" => "PLACED", "orderId" => "ORD-1" } ]
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:poll_events).and_return(
      IntegrationsKit::Result.success(message: "ok", data: { events: events })
    )
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:acknowledge_events).and_return(
      IntegrationsKit::Result.failure(message: "iFood: acknowledge falhou")
    )
    allow(Rails.logger).to receive(:error)

    described_class.perform_now

    expect(Rails.logger).to have_received(:error).with(/acknowledge falhou/)
    expect(within_tenant { AuditLog.where(action: "marketplace_event").count }).to eq(1)
  end

  it "skips businesses without marketplace credentials" do
    expect(IntegrationsKit::IfoodMarketplaceProvider).not_to receive(:poll_events)
    described_class.perform_now
  end

  it "polls each business with its own credentials (no cross-tenant bleed)" do
    events = [ { "eventId" => "EV2", "code" => "PLACED", "orderId" => "ORD-2" } ]

    first_business = create(:business, integration_adapter_mode: "live")
    second_business = create(:business, integration_adapter_mode: "live")

    [ [ first_business, "SEC_A" ], [ second_business, "SEC_B" ] ].each do |b, secret|
      Tenancy.with_business(b) do
        create(:integration_setting, business: b, provider_key: "marketplace", credentials: { client_id: "CID_#{secret}", client_secret: secret }, enabled: true)
      end
    end

    received_settings = []
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:poll_events) do |settings:, args:|
      received_settings << settings
      IntegrationsKit::Result.success(message: "ok", data: { events: events })
    end
    allow(IntegrationsKit::IfoodMarketplaceProvider).to receive(:acknowledge_events)
      .and_return(IntegrationsKit::Result.success(message: "ok", metadata: {}))
    allow(Rails.logger).to receive(:info)

    described_class.perform_now

    expect(received_settings.map { |s| s[:client_secret] }).to contain_exactly("SEC_A", "SEC_B")
    expect(IntegrationsKit::IfoodMarketplaceProvider).to have_received(:poll_events)
      .with(settings: hash_including(client_secret: "SEC_A"), args: {})
    expect(IntegrationsKit::IfoodMarketplaceProvider).to have_received(:poll_events)
      .with(settings: hash_including(client_secret: "SEC_B"), args: {})
    expect(within_tenant { AuditLog.where(action: "marketplace_event").count }).to eq(0)
    expect(Tenancy.with_business(first_business) { AuditLog.where(action: "marketplace_event").count }).to eq(1)
  end
end
