require "rails_helper"
require Rails.root.join("app/channels/application_cable/channel")
require Rails.root.join("app/channels/application_cable/connection")

RSpec.describe "Application Cable tenancy" do
  it "binds a connection to the authenticated user's business" do
    business = create(:business)
    user = Tenancy.with_business(business) { create(:user, business: business) }
    connection = ApplicationCable::Connection.allocate
    warden = double("warden", user: user)
    allow(connection).to receive(:env).and_return({ "warden" => warden })

    connection.connect

    expect(connection.current_user).to eq(user)
    expect(connection.business).to eq(business)
  end

  it "rejects unauthenticated connections" do
    connection = ApplicationCable::Connection.allocate
    allow(connection).to receive(:env).and_return({ "warden" => double("warden", user: nil) })
    allow(connection).to receive(:logger).and_return(double("logger", error: nil))

    expect { connection.connect }
      .to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
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
