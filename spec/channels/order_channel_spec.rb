require "rails_helper"
require Rails.root.join("app/channels/application_cable/channel")

RSpec.describe OrderChannel do
  it "streams from the business order stream when subscribed" do
    channel = described_class.allocate
    business = create(:business)
    allow(channel).to receive(:connection).and_return(Struct.new(:business).new(business))
    allow(channel).to receive(:stream_from)

    channel.subscribed

    expect(channel).to have_received(:stream_from).with("orders_#{business.id}")
  end

  it "names the stream after the business id" do
    expect(described_class.stream_name("abc-123")).to eq("orders_abc-123")
  end
end
