require "rails_helper"

RSpec.describe BusinessJob do
  it "enqueues while the requested business is current" do
    business = create(:business)
    allow(described_class).to receive(:perform_later)

    described_class.perform_later_for(business, "report")

    expect(described_class).to have_received(:perform_later).with("report")
    expect(Current.business).to be_nil
  end
end
