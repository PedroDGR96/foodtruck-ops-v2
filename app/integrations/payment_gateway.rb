# Contract for financial transaction providers (authorization, capture, refund
# and status checks). Real adapters subclass and implement the methods below,
# returning the documented Hash shapes; the mock variant provides deterministic
# sandbox behavior for tests and local development.
class PaymentGateway
  def self.authorize(settings:, amount:, order_id:, metadata: {})
    raise NotImplementedError
  end

  def self.capture(settings:, order_id:, auth_token:)
    raise NotImplementedError
  end

  def self.refund(settings:, amount:, order_id:)
    raise NotImplementedError
  end

  def self.status(settings:, order_id:)
    raise NotImplementedError
  end
end
