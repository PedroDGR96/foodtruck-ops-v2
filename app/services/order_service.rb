# Orchestrates the POS payment flow: marketplace order intake, payment
# authorization/capture, and a refund fallback if capture fails. Adapters are
# injected so the flow can be exercised against deterministic mocks or real
# providers without changes.
class OrderService
  Result = Struct.new(:success, :message, :payment_status, :order_num, :details, keyword_init: true)

  def initialize(payment_gateway:, marketplace_provider:)
    @payment_gateway = payment_gateway
    @marketplace_provider = marketplace_provider
  end

  def process_pos_payment(order_details:, payment_method:, amount:, order_id:)
    settings = { currency: "BRL" }

    marketplace_result = @marketplace_provider.create_order(
      settings: { merchant_id: order_details[:merchant_id], platform: order_details[:platform] },
      args: {
        merchant_id: order_details[:merchant_id],
        platform: order_details[:platform],
        user_id: order_details[:user_id],
        items_count: order_details[:items_count],
        total_amount: order_details[:total_amount]
      }
    )
    return failure("Failed to create marketplace order.", marketplace_result[:message]) unless marketplace_result[:success]

    order_num = marketplace_result.dig(:data, :order_num)

    auth_result = @payment_gateway.authorize(
      settings: settings, amount: amount, order_id: order_num,
      metadata: { source: "pos_system", payment_method: payment_method }
    )
    return failure("Payment authorization failed.", auth_result[:message]) unless auth_result[:success]

    auth_token = auth_result.dig(:metadata, :auth_token)
    capture_result = @payment_gateway.capture(settings: settings, order_id: order_num, auth_token: auth_token)

    unless capture_result[:success]
      refund_result = @payment_gateway.refund(settings: settings, amount: amount, order_id: order_num)
      return failure("Payment capture failed. Refund initiated.", refund_result[:message], order_num: order_num)
    end

    Result.new(
      success: true,
      message: "Order #{order_num} processed successfully via POS.",
      payment_status: "paid",
      order_num: order_num,
      details: capture_result[:message]
    )
  rescue StandardError => e
    Rails.logger.error "[OrderService] POS processing failed for order #{order_id}: #{e.message}"
    failure("Critical error during POS processing.", e.message)
  end

  private

  def failure(message, details, order_num: nil)
    Result.new(success: false, message: message, order_num: order_num, details: details)
  end
end
