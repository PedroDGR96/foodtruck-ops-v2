require "rails_helper"

RSpec.describe MockMapsProvider, type: :model do
  describe ".geocode" do
    it "returns the supplied lat/lng when provided" do
      result = described_class.geocode(
        settings: {},
        args: { address: "Rua 1, SP", lat: "-23.55", lng: "-46.63", accuracy: "rooftop" }
      )

      expect(result[:success]).to be true
      expect(result[:data][:lat]).to eq(-23.55)
      expect(result[:data][:lng]).to eq(-46.63)
    end

    it "derives deterministic coordinates from the address when lat/lng are missing" do
      first = described_class.geocode(settings: {}, args: { address: "Rua A" })
      second = described_class.geocode(settings: {}, args: { address: "Rua A" })
      third = described_class.geocode(settings: {}, args: { address: "Rua B" })

      expect(first[:data][:lat]).to eq(second[:data][:lat])
      expect(first[:data][:lat]).not_to eq(third[:data][:lat])
    end

    it "rejects an empty address" do
      expect { described_class.geocode(settings: {}, args: { address: "" }) }
        .to raise_error(ArgumentError, /empty/i)
    end
  end

  describe ".distance" do
    it "returns deterministic meters derived from origin/destination" do
      first = described_class.distance(settings: {}, args: { origin: "A", destination: "B" })
      second = described_class.distance(settings: {}, args: { origin: "A", destination: "B" })

      expect(first[:success]).to be true
      expect(first[:data][:meters]).to eq(second[:data][:meters])
      expect(first[:data][:km]).to eq((first[:data][:meters] / 1000.0).round(2))
    end

    it "rejects an empty origin or destination" do
      expect { described_class.distance(settings: {}, args: { origin: "", destination: "B" }) }
        .to raise_error(ArgumentError, /empty/i)
    end
  end
end
