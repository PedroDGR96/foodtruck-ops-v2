# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment do
  it "has valid statuses" do
    expect(Payment.statuses).to include(:succeeded, :refunded)
  end
end
