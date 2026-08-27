require "rails_helper"

RSpec.describe ConsentRecord, type: :model do
  let(:business) { create(:business) }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  it "builds a valid consent record" do
    within_tenant do
      consent = build(:consent_record, business: business)
      expect(consent).to be_valid
    end
  end

  describe "validations" do
    it "requires a consent_type" do
      within_tenant do
        consent = build(:consent_record, business: business, consent_type: "")
        expect(consent).not_to be_valid
        expect(consent.errors[:consent_type]).to be_present
      end
    end

    it "validates consent_type inclusion" do
      within_tenant do
        consent = build(:consent_record, business: business, consent_type: "invalid")
        expect(consent).not_to be_valid
      end
    end

    it "accepts valid consent_types" do
      %w[privacy_policy marketing analytics].each do |type|
        within_tenant do
          consent = build(:consent_record, business: business, consent_type: type)
          expect(consent).to be_valid
        end
      end
    end

    it "requires consent_version" do
      within_tenant do
        consent = build(:consent_record, business: business, consent_version: "")
        expect(consent).not_to be_valid
        expect(consent.errors[:consent_version]).to be_present
      end
    end

    it "requires consent_text_hash" do
      within_tenant do
        consent = build(:consent_record, business: business, consent_text_hash: "")
        expect(consent).not_to be_valid
        expect(consent.errors[:consent_text_hash]).to be_present
      end
    end

    it "requires data_subject_email when user is not present" do
      within_tenant do
        consent = build(:consent_record, business: business, user: nil, data_subject_email: "")
        expect(consent).not_to be_valid
        expect(consent.errors[:data_subject_email]).to be_present
      end
    end

    it "does not require data_subject_email when user is present" do
      within_tenant do
        user = create(:user, :owner, business: business)
        consent = build(:consent_record, business: business, user: user, data_subject_email: nil)
        expect(consent).to be_valid
      end
    end
  end

  describe "scopes" do
    it ".active returns non-withdrawn, granted consents" do
      within_tenant do
        active = create(:consent_record, business: business)
        create(:consent_record, :withdrawn, business: business)

        expect(ConsentRecord.active.count).to eq(1)
        expect(ConsentRecord.active.first).to eq(active)
      end
    end

    it ".for_email filters by email" do
      within_tenant do
        create(:consent_record, business: business, data_subject_email: "a@test.com")
        create(:consent_record, business: business, data_subject_email: "b@test.com")

        expect(ConsentRecord.for_email("a@test.com").count).to eq(1)
      end
    end
  end

  describe "#withdraw!" do
    it "marks consent as withdrawn" do
      within_tenant do
        consent = create(:consent_record, business: business)
        consent.withdraw!

        expect(consent.reload.granted).to be false
        expect(consent.withdrawn_at).to be_present
      end
    end
  end

  describe ".granted?" do
    it "returns true when latest consent is granted and not withdrawn" do
      within_tenant do
        create(:consent_record, business: business, data_subject_email: "test@test.com", consent_type: "marketing")
        expect(ConsentRecord.granted?("test@test.com", "marketing")).to be true
      end
    end

    it "returns false when latest consent is withdrawn" do
      within_tenant do
        create(:consent_record, :withdrawn, business: business, data_subject_email: "test@test.com", consent_type: "marketing")
        expect(ConsentRecord.granted?("test@test.com", "marketing")).to be false
      end
    end

    it "returns nil when no consent exists" do
      within_tenant do
        expect(ConsentRecord.granted?("nobody@test.com", "marketing")).to be_nil
      end
    end
  end

  describe "tenancy" do
    it "only exposes consent records from the current business" do
      record = within_tenant { create(:consent_record, business: business) }
      other = create(:business)
      Tenancy.with_business(other) { create(:consent_record, business: other) }

      within_tenant { expect(ConsentRecord.pluck(:id)).to eq([ record.id ]) }
    end
  end
end
