require "rails_helper"
require Rails.root.join("app/channels/application_cable/channel")
require Rails.root.join("app/channels/application_cable/connection")

RSpec.describe "Application Cable tenancy" do
  it "binds a connection to the current business" do
    business = create(:business)
    connection = ApplicationCable::Connection.allocate
    allow(connection).to receive(:business=)

    Current.set(business: business) { connection.connect }

    expect(connection).to have_received(:business=).with(business)
  end

  it "wraps subscription and message execution in the business context" do
    channel = ApplicationCable::Channel.allocate
    business = create(:business)
    allow(channel).to receive(:connection).and_return(Struct.new(:business).new(business))
    allow(channel).to receive(:with_business)

    channel.subscribe_to_channel
    channel.perform_action({})

    expect(channel).to have_received(:with_business).twice
    allow(channel).to receive(:with_business).and_call_original
    expect(Tenancy).to receive(:with_business).with(business).and_yield
    channel.send(:with_business) { :performed }
  end
end
