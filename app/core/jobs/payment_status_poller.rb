# Confirms gateway payments that were recorded as "pending" at checkout (e.g.
# a real Pix QR) once the provider reports approval. Runs only for businesses
# whose payment_gateway is in live mode; mock mode settles instantly at
# checkout so there is nothing to poll.
class PaymentStatusPoller < ApplicationJob
  queue_as :default

  def perform
    Business.where(integration_adapter_mode: "live").find_each do |business|
      process_business(business)
    rescue StandardError => e
      Rails.logger.error "[PaymentStatusPoller] negócio #{business.id} falhou: #{e.message}"
    end
  end

  private

  def process_business(business)
    Tenancy.with_business(business) do
      next if AdapterResolver.settings_for(Current.business, :payment_gateway)[:access_token].blank?

      gateway = AdapterResolver.resolve(Current.business, :payment_gateway)
      settings = AdapterResolver.settings_for(Current.business, :payment_gateway)

      Payment.where(status: :pending).includes(:order).find_each do |payment|
        poll_payment(gateway, settings, payment)
      end
    end
  end

  def poll_payment(gateway, settings, payment)
    result = gateway.status(settings: settings, order_id: payment.gateway_reference.to_s)
    unless result[:success]
      Rails.logger.warn "[PaymentStatusPoller] poll falhou: #{result[:message]}"
      return
    end

    case result.dig(:data, :state).to_s
    when "approved"
      Rails.logger.info "[PaymentStatusPoller] pagamento confirmado para order #{payment.order_id}"
      OrderLifecycle.new(payment.order, nil).confirm_payment!(payment)
    when "rejected", "failed", "cancelled"
      Rails.logger.warn "[PaymentStatusPoller] pagamento recusado para order #{payment.order_id}"
      payment.update!(status: :failed)
    end
  end
end
