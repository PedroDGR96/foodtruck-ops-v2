require "rails_helper"

RSpec.describe PrivacyIncident, type: :model do
  let(:business) { create(:business) }

  def within_tenant(&block)
    Tenancy.with_business(business, &block)
  end

  it "builds a valid privacy incident" do
    within_tenant do
      incident = build(:privacy_incident, business: business)
      expect(incident).to be_valid
    end
  end

  describe "validations" do
    it "requires title" do
      within_tenant do
        incident = build(:privacy_incident, business: business, title: "")
        expect(incident).not_to be_valid
        expect(incident.errors[:title]).to be_present
      end
    end

    it "requires description" do
      within_tenant do
        incident = build(:privacy_incident, business: business, description: "")
        expect(incident).not_to be_valid
      end
    end

    it "requires severity" do
      within_tenant do
        incident = build(:privacy_incident, business: business, severity: "")
        expect(incident).not_to be_valid
      end
    end

    it "validates severity inclusion" do
      within_tenant do
        incident = build(:privacy_incident, business: business, severity: "invalid")
        expect(incident).not_to be_valid
      end
    end

    it "accepts valid severities" do
      %w[low medium high critical].each do |sev|
        within_tenant do
          incident = build(:privacy_incident, business: business, severity: sev)
          expect(incident).to be_valid
        end
      end
    end

    it "auto-sets detected_at when nil" do
      within_tenant do
        incident = build(:privacy_incident, business: business, detected_at: nil)
        expect(incident).to be_valid
        expect(incident.detected_at).to be_present
      end
    end
  end

  describe "auto-set detected_at and deadline" do
    it "sets detected_at to now on create" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        expect(incident.detected_at).to be_present
      end
    end

    it "sets anpd_notification_deadline 48h after detected_at" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        expected_deadline = incident.detected_at + 48.hours
        expect(incident.anpd_notification_deadline).to be_within(1.second).of(expected_deadline)
      end
    end
  end

  describe "#anpd_notification_overdue?" do
    it "returns true when deadline passed and not yet notified" do
      within_tenant do
        incident = create(:privacy_incident, :anpd_overdue, business: business)
        expect(incident.anpd_notification_overdue?).to be true
      end
    end

    it "returns false when already notified" do
      within_tenant do
        incident = create(:privacy_incident, :anpd_overdue, :notified, business: business)
        expect(incident.anpd_notification_overdue?).to be false
      end
    end

    it "returns false when deadline has not passed" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        expect(incident.anpd_notification_overdue?).to be false
      end
    end
  end

  describe "#notify_anpd!" do
    it "sets anpd_notified_at and status to notified" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        incident.notify_anpd!

        expect(incident.anpd_notified_at).to be_present
        expect(incident.status).to eq("notified")
      end
    end
  end

  describe "#notify_subjects!" do
    it "sets subjects_notified_at" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        incident.notify_subjects!

        expect(incident.subjects_notified_at).to be_present
      end
    end
  end

  describe "#contain!" do
    it "sets status to contained with remediation notes" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        incident.contain!(notes: "Credenciais rotacionadas")

        expect(incident.status).to eq("contained")
        expect(incident.remediation_notes).to eq("Credenciais rotacionadas")
      end
    end
  end

  describe "#resolve!" do
    it "sets status to resolved" do
      within_tenant do
        incident = create(:privacy_incident, business: business)
        incident.resolve!(notes: "Incidente resolvido")

        expect(incident.status).to eq("resolved")
        expect(incident.remediation_notes).to include("Incidente resolvido")
      end
    end
  end

  describe "scopes" do
    it ".open_incidents excludes resolved" do
      within_tenant do
        create(:privacy_incident, business: business, status: "detected")
        create(:privacy_incident, :resolved, business: business)
        expect(PrivacyIncident.open_incidents.count).to eq(1)
      end
    end

    it ".critical returns unresolved critical incidents" do
      within_tenant do
        create(:privacy_incident, :critical, business: business)
        create(:privacy_incident, :critical, :resolved, business: business)
        expect(PrivacyIncident.critical.count).to eq(1)
      end
    end
  end

  describe "tenancy" do
    it "only exposes incidents from the current business" do
      incident = within_tenant { create(:privacy_incident, business: business) }
      other = create(:business)
      Tenancy.with_business(other) { create(:privacy_incident, business: other) }

      within_tenant { expect(PrivacyIncident.pluck(:id)).to eq([ incident.id ]) }
    end
  end
end
