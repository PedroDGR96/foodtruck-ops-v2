# frozen_string_literal: true

require "rails_helper"

RSpec.describe Business, type: :model do
  let(:business) { create(:business) }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  it "is valid with the factory attributes" do
    within_tenant { expect(business).to be_valid }
  end

  describe "validations" do
    it "requires a name" do
      within_tenant do
        b = build(:business, name: "")
        expect(b).not_to be_valid
        expect(b.errors[:name]).to be_present
      end
    end

    it "requires a currency" do
      within_tenant do
        b = build(:business, currency: "")
        expect(b).not_to be_valid
        expect(b.errors[:currency]).to be_present
      end
    end

    it "requires a timezone" do
      within_tenant do
        b = build(:business, timezone: "")
        expect(b).not_to be_valid
        expect(b.errors[:timezone]).to be_present
      end
    end

    it "rejects a negative delivery_fee" do
      within_tenant do
        b = build(:business, delivery_fee: -1)
        expect(b).not_to be_valid
        expect(b.errors[:delivery_fee]).to be_present
      end
    end

    it "allows a nil delivery_fee" do
      within_tenant do
        b = build(:business, delivery_fee: nil)
        expect(b).to be_valid
      end
    end
  end

  describe "associations" do
    it "exposes tenant-scoped children" do
      within_tenant do
        user = create(:user, :owner, business: business)
        customer = create(:customer, business: business)
        expect(business.users).to include(user)
        expect(business.customers).to include(customer)
      end
    end
  end
end
