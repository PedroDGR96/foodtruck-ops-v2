# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BusinessScoped concern" do
  it "raises when business_id is unset" do
    expect { Current.business_id! }.to raise_error(Tenancy::TenantNotSetError)
  end
end
