# Deterministic, stateless mock for PaymentGateway. Successful authorizations
# always yield the same token for a given order id, so capture/status can be
# asserted without any shared mutable state.
class MockPaymentGateway < PaymentGateway
  def self.authorize(settings:, amount:, order_id:, metadata: {})
    auth_token = "mock_auth_#{order_id}"
    {
      success: true,
      message: "Payment of #{amount} authorized for order #{order_id}",
      metadata: {
        auth_token: auth_token,
        order_id: order_id,
        amount: amount.to_f.round(2),
        currency: settings.fetch(:currency, "BRL"),
        source: metadata[:source]
      }
    }
  end

  def self.capture(settings:, order_id:, auth_token:)
    return failure("Invalid authorization token for order #{order_id}") unless auth_token == "mock_auth_#{order_id}"

    {
      success: true,
      message: "Payment captured for order #{order_id}",
      metadata: { order_id: order_id, captured: true }
    }
  end

  def self.refund(settings:, amount:, order_id:)
    {
      success: true,
      message: "Refund of #{amount} initiated for order #{order_id}",
      metadata: { order_id: order_id, amount: amount.to_f.round(2) }
    }
  end

  def self.status(settings:, order_id:)
    {
      success: true,
      message: "Payment status available for order #{order_id}",
      data: {
        order_id: order_id,
        state: "paid",
        authorized: true,
        captured: true,
        refunded: false,
        amount: 0.0
      }
    }
  end

  def self.failure(message)
    { success: false, message: message, metadata: {} }
  end
  private_class_method :failure
end
