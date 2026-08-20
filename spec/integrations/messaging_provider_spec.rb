require "rails_helper"

RSpec.describe MessagingProvider do
  it { expect { described_class.send_whatsapp(settings: {}, phone: nil, message: nil) }.to raise_error(NotImplementedError) }
  it { expect { described_class.send_sms(settings: {}, phone: nil, message: nil) }.to raise_error(NotImplementedError) }
  it { expect { described_class.send_email(settings: {}, email: nil, message: nil) }.to raise_error(NotImplementedError) }
  it { expect { described_class.bulk_send(settings: {}, messages: nil) }.to raise_error(NotImplementedError) }
end
