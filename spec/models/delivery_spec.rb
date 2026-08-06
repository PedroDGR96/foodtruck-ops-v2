require "rails_helper"

RSpec.describe DeliveryAddress do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "validations" do
    it "requires street, city and state" do
      address = within_tenant { build(:delivery_address, business: business, street: nil, city: nil, state: nil) }

      expect(address).not_to be_valid
      expect(address.errors[:street]).to be_present
      expect(address.errors[:city]).to be_present
      expect(address.errors[:state]).to be_present
    end

    it "is valid with required fields" do
      order = within_tenant { create(:order, business: business) }
      address = within_tenant { build(:delivery_address, business: business, order: order) }

      expect(address).to be_valid
    end
  end

  describe "tenancy" do
    it "is scoped to the current business" do
      order = within_tenant { create(:order, business: business) }
      address = within_tenant { create(:delivery_address, business: business, order: order) }

      other = create(:business)
      Tenancy.with_business(other) { expect(DeliveryAddress.pluck(:id)).to be_empty }
      Tenancy.with_business(business) { expect(DeliveryAddress.pluck(:id)).to eq([ address.id ]) }
    end
  end
end

RSpec.describe Delivery do
  let(:business) { create(:business) }

  around do |example|
    Tenancy.with_business(business) { example.run }
  end

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  describe "statuses" do
    it "defaults to pending" do
      delivery = within_tenant { build(:delivery, business: business) }

      expect(delivery).to be_pending
    end

    it "exposes the delivery status enum" do
      delivery = within_tenant { build(:delivery, business: business, status: "out_for_delivery") }

      expect(delivery).to be_out_for_delivery
    end
  end

  describe "tenancy" do
    it "is scoped to the current business" do
      order = within_tenant { create(:order, business: business) }
      delivery = within_tenant { create(:delivery, business: business, order: order) }

      other = create(:business)
      Tenancy.with_business(other) { expect(Delivery.pluck(:id)).to be_empty }
      Tenancy.with_business(business) { expect(Delivery.pluck(:id)).to eq([ delivery.id ]) }
    end
  end
end
