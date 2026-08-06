require "rails_helper"

RSpec.describe KitchenChannel, type: :channel do
  it "streams from the business kitchen stream" do
    business = create(:business)
    stub_connection(business: business)

    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(KitchenChannel.stream_name(business.id))
  end

  it "builds a namespaced stream name per business" do
    expect(KitchenChannel.stream_name(42)).to eq("kitchen_42")
  end
end
