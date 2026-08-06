require "rails_helper"

RSpec.describe BusinessDay do
  describe ".window" do
    it "returns a day range in the business timezone" do
      business = create(:business, timezone: "America/Sao_Paulo")
      tz = ActiveSupport::TimeZone["America/Sao_Paulo"]

      window = described_class.window(business, Date.new(2026, 8, 4))

      expect(window.first).to eq(tz.local(2026, 8, 4))
      expect(window.last).to eq(tz.local(2026, 8, 5))
    end

    it "uses current date when no date is given" do
      business = create(:business, timezone: "UTC")

      window = described_class.window(business)

      expect(window).to be_a(Range)
      expect(window.first.to_date).to eq(Date.current)
    end
  end
end
