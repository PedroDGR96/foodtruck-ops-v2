require "rails_helper"

RSpec.describe DataSubjectRequest, type: :model do
  let(:business) { create(:business) }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  it "builds a valid data subject request" do
    within_tenant do
      dsar = build(:data_subject_request, business: business)
      expect(dsar).to be_valid
    end
  end

  describe "validations" do
    it "requires data_subject_email" do
      within_tenant do
        dsar = build(:data_subject_request, business: business, data_subject_email: "")
        expect(dsar).not_to be_valid
        expect(dsar.errors[:data_subject_email]).to be_present
      end
    end

    it "validates email format" do
      within_tenant do
        dsar = build(:data_subject_request, business: business, data_subject_email: "not-an-email")
        expect(dsar).not_to be_valid
      end
    end

    it "requires request_type" do
      within_tenant do
        dsar = build(:data_subject_request, business: business, request_type: "")
        expect(dsar).not_to be_valid
      end
    end

    it "validates request_type inclusion" do
      within_tenant do
        dsar = build(:data_subject_request, business: business, request_type: "invalid")
        expect(dsar).not_to be_valid
      end
    end

    it "accepts valid request_types" do
      %w[access correction deletion portability revocation].each do |type|
        within_tenant do
          dsar = build(:data_subject_request, business: business, request_type: type)
          expect(dsar).to be_valid
        end
      end
    end

    it "validates status inclusion" do
      within_tenant do
        dsar = build(:data_subject_request, business: business, status: "invalid")
        expect(dsar).not_to be_valid
      end
    end
  end

  describe "deadline" do
    it "sets a 15-day deadline on creation" do
      within_tenant do
        dsar = create(:data_subject_request, business: business)
        expect(dsar.deadline_at).to be_present
        expect(dsar.deadline_at.to_date).to eq(15.days.from_now.to_date)
      end
    end

    it "does not override an existing deadline" do
      custom_deadline = 10.days.from_now
      within_tenant do
        dsar = create(:data_subject_request, business: business, deadline_at: custom_deadline)
        expect(dsar.deadline_at.to_date).to eq(custom_deadline.to_date)
      end
    end
  end

  describe "#overdue?" do
    it "returns true when deadline passed and status is pending" do
      within_tenant do
        dsar = create(:data_subject_request, :overdue, business: business, status: "pending")
        expect(dsar.overdue?).to be true
      end
    end

    it "returns false when deadline passed but status is completed" do
      within_tenant do
        dsar = create(:data_subject_request, :overdue, :completed, business: business)
        expect(dsar.overdue?).to be false
      end
    end

    it "returns false when deadline is in the future" do
      within_tenant do
        dsar = create(:data_subject_request, business: business, deadline_at: 10.days.from_now)
        expect(dsar.overdue?).to be false
      end
    end
  end

  describe "#days_remaining" do
    it "returns positive days when deadline is in the future" do
      within_tenant do
        dsar = create(:data_subject_request, business: business, deadline_at: 10.days.from_now)
        expect(dsar.days_remaining).to be >= 9
      end
    end

    it "returns negative days when overdue" do
      within_tenant do
        dsar = create(:data_subject_request, :overdue, business: business)
        expect(dsar.days_remaining).to be < 0
      end
    end
  end

  describe "#complete!" do
    it "sets status to completed and completed_at" do
      within_tenant do
        dsar = create(:data_subject_request, business: business)
        dsar.complete!(notes: "Dados exportados")

        expect(dsar.status).to eq("completed")
        expect(dsar.completed_at).to be_present
        expect(dsar.response_notes).to eq("Dados exportados")
      end
    end
  end

  describe "#reject!" do
    it "sets status to rejected" do
      within_tenant do
        dsar = create(:data_subject_request, business: business)
        dsar.reject!(notes: "Solicitação inválida")

        expect(dsar.status).to eq("rejected")
        expect(dsar.completed_at).to be_present
      end
    end
  end

  describe "#start_progress!" do
    it "transitions from pending to in_progress" do
      within_tenant do
        dsar = create(:data_subject_request, business: business)
        dsar.start_progress!
        expect(dsar.status).to eq("in_progress")
      end
    end

    it "does not transition from completed" do
      within_tenant do
        dsar = create(:data_subject_request, :completed, business: business)
        dsar.start_progress!
        expect(dsar.status).to eq("completed")
      end
    end
  end

  describe "scopes" do
    it ".pending returns pending requests" do
      within_tenant do
        create(:data_subject_request, business: business, status: "pending")
        create(:data_subject_request, :completed, business: business)
        expect(DataSubjectRequest.pending.count).to eq(1)
      end
    end

    it ".overdue returns pending requests past deadline" do
      within_tenant do
        create(:data_subject_request, :overdue, business: business, status: "pending")
        create(:data_subject_request, business: business, deadline_at: 10.days.from_now)
        expect(DataSubjectRequest.overdue.count).to eq(1)
      end
    end

    it ".due_soon returns requests due within deadline" do
      within_tenant do
        create(:data_subject_request, :due_soon, business: business)
        create(:data_subject_request, business: business, deadline_at: 20.days.from_now)
        expect(DataSubjectRequest.due_soon.count).to eq(1)
      end
    end
  end

  describe "tenancy" do
    it "only exposes requests from the current business" do
      dsar = within_tenant { create(:data_subject_request, business: business) }
      other = create(:business)
      Tenancy.with_business(other) { create(:data_subject_request, business: other) }

      within_tenant { expect(DataSubjectRequest.pluck(:id)).to eq([ dsar.id ]) }
    end
  end
end
