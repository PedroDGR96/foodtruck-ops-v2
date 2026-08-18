require "rails_helper"

RSpec.describe FiscalProvider do
  it { expect { described_class.emit_nfc_e(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.emit_nf_e(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.status(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
  it { expect { described_class.cancel(settings: {}, args: {}) }.to raise_error(NotImplementedError) }
end
