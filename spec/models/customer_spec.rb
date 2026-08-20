require "rails_helper"

RSpec.describe Customer, type: :model do
  let(:business) { create(:business) }

  def build_customer(**overrides)
    build(:customer, business: business, **overrides)
  end

  it "builds a valid customer" do
    Tenancy.with_business(business) { expect(build_customer).to be_valid }
  end

  it "requires a name" do
    Tenancy.with_business(business) do
      customer = build_customer(name: "")
      expect(customer).not_to be_valid
      expect(customer.errors[:name]).to be_present
    end
  end

  describe "phone normalization" do
    it "stores digits only" do
      Tenancy.with_business(business) do
        customer = create(:customer, business: business, phone: "(11) 91234-5678")
        expect(customer.phone).to eq("11912345678")
      end
    end

    it "strips the +55 country code" do
      Tenancy.with_business(business) do
        customer = create(:customer, business: business, phone: "+55 11 98765-4321")
        expect(customer.phone).to eq("11987654321")
      end
    end

    it "strips a leading zero trunk prefix" do
      Tenancy.with_business(business) do
        customer = create(:customer, business: business, phone: "011 98765-4321")
        expect(customer.phone).to eq("11987654321")
      end
    end

    it "normalizes whatsapp the same way" do
      Tenancy.with_business(business) do
        customer = create(:customer, business: business, whatsapp: "+55 (11) 91234-5678")
        expect(customer.whatsapp).to eq("11912345678")
      end
    end

    it "turns a blank phone into nil" do
      Tenancy.with_business(business) do
        customer = create(:customer, business: business, phone: "   ")
        expect(customer.phone).to be_nil
      end
    end

    it "rejects a phone with too few digits" do
      Tenancy.with_business(business) do
        customer = build_customer(phone: "1234")
        expect(customer).not_to be_valid
        expect(customer.errors[:phone]).to be_present
      end
    end
  end

  describe "uniqueness within a business" do
    it "rejects a duplicated normalized phone" do
      Tenancy.with_business(business) { create(:customer, business: business, phone: "(11) 91234-5678") }

      Tenancy.with_business(business) do
        duplicate = build_customer(phone: "11 91234-5678")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:phone]).to be_present
      end
    end

    it "allows the same phone across businesses" do
      other = create(:business)
      Tenancy.with_business(business) { create(:customer, business: business, phone: "11912345678") }

      Tenancy.with_business(other) { expect(build(:customer, business: other, phone: "11912345678")).to be_valid }
    end

    it "allows multiple customers without a phone" do
      Tenancy.with_business(business) { create(:customer, business: business, phone: nil) }
      Tenancy.with_business(business) { expect(build_customer(phone: nil)).to be_valid }
    end
  end

  describe "soft delete" do
    it "excludes discarded customers from the default scope" do
      customer = Tenancy.with_business(business) { create(:customer, business: business) }
      Tenancy.with_business(business) { customer.discard! }

      Tenancy.with_business(business) do
        expect(Customer.find_by(id: customer.id)).to be_nil
        expect(Customer.with_discarded.find_by(id: customer.id)).to be_present
      end
    end

    it "frees a phone for reuse after discarding" do
      customer = Tenancy.with_business(business) { create(:customer, business: business, phone: "11912345678") }
      Tenancy.with_business(business) { customer.discard! }

      Tenancy.with_business(business) { expect(build_customer(phone: "11912345678")).to be_valid }
    end
  end

  describe "search" do
    it "finds customers by name or phone" do
      Tenancy.with_business(business) do
        create(:customer, business: business, name: "Maria Silva", phone: "11912345678")
        create(:customer, business: business, name: "João Souza", phone: "11987654321")
      end

      Tenancy.with_business(business) do
        expect(Customer.search("maria").pluck(:name)).to eq([ "Maria Silva" ])
        expect(Customer.search("9876").pluck(:name)).to eq([ "João Souza" ])
      end
    end

    it "returns an empty relation for a blank term" do
      Tenancy.with_business(business) do
        create(:customer, business: business)
        expect(Customer.search(nil)).to be_empty
        expect(Customer.search("   ")).to be_empty
      end
    end
  end

  describe "tenancy" do
    it "only exposes customers from the current business" do
      first = Tenancy.with_business(business) { create(:customer, business: business) }
      other = create(:business)
      Tenancy.with_business(other) { create(:customer, business: other) }

      Tenancy.with_business(business) { expect(Customer.pluck(:id)).to eq([ first.id ]) }
    end
  end
end
