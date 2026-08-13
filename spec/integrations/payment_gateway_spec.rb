require "rails_helper"

# The abstract adapter is a contract: subclasses (e.g. MockPaymentGateway)
# implement the real behavior. The base methods must raise until then, so the
# contract is explicit and callers can't silently use an unimplemented adapter.
RSpec.describe PaymentGateway do
  it { expect { described_class.authorize(settings: {}, amount: 0, order_id: nil) }.to raise_error(NotImplementedError) }
  it { expect { described_class.capture(settings: {}, order_id: nil, auth_token: nil) }.to raise_error(NotImplementedError) }
  it { expect { described_class.refund(settings: {}, amount: 0, order_id: nil) }.to raise_error(NotImplementedError) }
  it { expect { described_class.status(settings: {}, order_id: nil) }.to raise_error(NotImplementedError) }
end
