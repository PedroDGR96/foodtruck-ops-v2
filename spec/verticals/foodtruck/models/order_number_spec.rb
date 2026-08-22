# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order, type: :model do
  it "assigns sequential numbers per business" do
    business = create(:business)
    Tenancy.with_business(business) do
      first = create(:order, business: business)
      second = create(:order, business: business)

      expect(first.number).to eq(1)
      expect(second.number).to eq(2)
    end
  end

  it "starts numbering independently per business" do
    a = create(:business)
    b = create(:business)
    Tenancy.with_business(a) { create(:order, business: a) }
    Tenancy.with_business(b) do
      expect(create(:order, business: b).number).to eq(1)
    end
  end
end
