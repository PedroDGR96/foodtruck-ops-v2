require "rails_helper"

RSpec.describe PaymentStatusPoller do
  let(:business) { create(:business, integration_adapter_mode: "live") }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  def gateway_credentials!
    within_tenant do
      create(:integration_setting, business: business, provider_key: "payment_gateway", credentials: { access_token: "APP_USR_TEST" }, enabled: true)
    end
  end

  def pending_payment(order:, amount:)
    payment = within_tenant { order.payments.build(method: "pix", amount: amount) }
    within_tenant { OrderLifecycle.new(order, nil).pending_payment!(payment) }
    payment
  end

  it "confirms a pending gateway payment when the provider reports approved" do
    gateway_credentials!
    order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
    payment = pending_payment(order:, amount: 30.0)

    allow(IntegrationsKit::MercadoPagoGateway).to receive(:status)
      .with(settings: hash_including(access_token: "APP_USR_TEST"), order_id: payment.gateway_reference.to_s)
      .and_return(IntegrationsKit::Result.success(message: "Status approved", data: { state: "approved" }))

    described_class.perform_now

    within_tenant { payment.reload }
    expect(payment).to be_succeeded
    expect(within_tenant { order.reload.payment_status }).to eq("paid")
  end

  it "marks the payment failed when the provider rejects it" do
    gateway_credentials!
    order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
    payment = pending_payment(order:, amount: 30.0)

    allow(IntegrationsKit::MercadoPagoGateway).to receive(:status).and_return(
      IntegrationsKit::Result.success(message: "Status rejected", data: { state: "rejected" })
    )

    described_class.perform_now

    within_tenant { payment.reload }
    expect(payment).to be_failed
  end

  it "leaves the payment pending when the poll itself fails" do
    gateway_credentials!
    order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
    payment = pending_payment(order:, amount: 30.0)

    allow(IntegrationsKit::MercadoPagoGateway).to receive(:status).and_return(
      IntegrationsKit::Result.failure(message: "Mercado Pago: HTTP 500")
    )

    described_class.perform_now

    within_tenant { payment.reload }
    expect(payment).to be_pending
  end

  it "skips businesses without gateway credentials" do
    order = within_tenant { create(:order, :open, business: business, total: 30.0, subtotal: 30.0) }
    pending_payment(order:, amount: 30.0)

    expect(IntegrationsKit::MercadoPagoGateway).not_to receive(:status)

    described_class.perform_now
  end

  it "does nothing for businesses still in mock mode" do
    mock_business = create(:business, integration_adapter_mode: "mock")
    Tenancy.with_business(mock_business) do
      create(:integration_setting, business: mock_business, provider_key: "payment_gateway", credentials: { access_token: "APP_USR_TEST" }, enabled: true)
      create(:order, :open, business: mock_business, total: 30.0, subtotal: 30.0)
    end

    expect(IntegrationsKit::MercadoPagoGateway).not_to receive(:status)

    described_class.perform_now
  end

  it "does not abort the batch when one business raises" do
    first_business = create(:business, integration_adapter_mode: "live")
    second_business = create(:business, integration_adapter_mode: "live")

    [ first_business, second_business ].each do |b|
      Tenancy.with_business(b) do
        create(:integration_setting, business: b, provider_key: "payment_gateway", credentials: { access_token: "APP_USR_#{b.id}" }, enabled: true)
        order = create(:order, :open, business: b, total: 30.0, subtotal: 30.0)
        payment = order.payments.build(method: "pix", amount: 30.0)
        OrderLifecycle.new(order, nil).pending_payment!(payment)
      end
    end

    allow(Rails.logger).to receive(:error)
    allow(IntegrationsKit::MercadoPagoGateway).to receive(:status) do |settings:, order_id:|
      raise "boom #{settings[:access_token]}" if settings[:access_token] == "APP_USR_#{first_business.id}"

      IntegrationsKit::Result.success(message: "Status approved", data: { state: "approved" })
    end

    described_class.perform_now

    first_payment = Tenancy.with_business(first_business) { first_business.orders.first.payments.first }
    second_payment = Tenancy.with_business(second_business) { second_business.orders.first.payments.first }
    expect(first_payment).to be_pending
    expect(second_payment).to be_succeeded
    expect(Rails.logger).to have_received(:error).with(/negócio #{first_business.id} falhou: boom APP_USR_#{first_business.id}/)
  end
end
