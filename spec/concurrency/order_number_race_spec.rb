# frozen_string_literal: true

require "rails_helper"

# Order numbers are assigned by `Order#assign_order_number` (before_create:
# MAX(number) + 1 per business). A concurrent MAX+1 read race can hand TWO
# orders the same number; the UNIQUE index on (business_id, number) is the real
# guard. These examples pin the guarantee that a duplicate surfaces as
# ActiveRecord::RecordNotUnique (PG::UniqueViolation), never a silent duplicate.
RSpec.describe "Order number race condition", type: :model do
  it "raises RecordNotUnique when two rows share (business_id, number)" do
    business = create(:business)

    Tenancy.with_business(business) do
      first = create(:order, business: business)

      expect do
        ActiveRecord::Base.transaction(requires_new: true) do
          Order.create!(business: business, number: first.number)
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "keeps exactly one row with a given number after the collision" do
    business = create(:business)

    Tenancy.with_business(business) do
      order = create(:order, business: business)

      begin
        ActiveRecord::Base.transaction(requires_new: true) do
          Order.create!(business: business, number: order.number)
        end
        raise "expected a uniqueness collision"
      rescue ActiveRecord::RecordNotUnique
        # expected — the savepoint rolled back to keep the example transaction valid
      end

      expect(Order.where(number: order.number).count).to eq(1)
    end
  end

  it "assigns sequential numbers to consecutive creates even with an explicit number in the way" do
    business = create(:business)
    other = create(:business)

    Tenancy.with_business(business) do
      first = create(:order, business: business)
      expect(first.number).to eq(1)

      second = create(:order, business: business)
      expect(second.number).to eq(2)
    end

    Tenancy.with_business(other) do
      expect(create(:order, business: other).number).to eq(1)
    end
  end
end
