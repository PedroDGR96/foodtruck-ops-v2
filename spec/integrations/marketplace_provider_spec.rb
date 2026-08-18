require "rails_helper"

RSpec.describe MarketplaceProvider do
  it { expect { described_class.create_order(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.update_order(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.cancel_order(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.status(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.webhook_verify(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
end
