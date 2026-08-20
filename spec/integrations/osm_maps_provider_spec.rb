require "rails_helper"

RSpec.describe OsmMapsProvider do
  let(:success_body) do
    '[{"display_name":"Rua Example, Porto Alegre","lat":"-30.0346","lon":"-51.2177","type":"road","osm_id":123,"importance":0.8}]'
  end

  def build_response(body:, status: :success)
    case status
    when :success
      response = Net::HTTPSuccess.new("1.1", "200", "OK")
      allow(response).to receive(:body).and_return(body)
      response
    when :rate_limit
      response = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      allow(response).to receive(:body).and_return(body)
      response
    when :error
      response = Net::HTTPServerError.new("1.1", "500", "Internal Server Error")
      allow(response).to receive(:body).and_return(body)
      response
    end
  end

  let(:http_double) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http_double)
    allow(http_double).to receive(:use_ssl=)
    allow(http_double).to receive(:open_timeout=)
    allow(http_double).to receive(:read_timeout=)
  end

  describe ".geocode" do
    it "returns coordinates for a valid address" do
      allow(http_double).to receive(:request).and_return(build_response(body: success_body))

      result = described_class.geocode(settings: {}, args: { address: "Rua Example, Porto Alegre" })

      expect(result[:success]).to be true
      expect(result[:data][:lat]).to eq(-30.0346)
      expect(result[:data][:lng]).to eq(-51.2177)
      expect(result[:data][:address]).to eq("Rua Example, Porto Alegre")
    end

    it "returns failure for empty results" do
      allow(http_double).to receive(:request).and_return(build_response(body: "[]"))

      result = described_class.geocode(settings: {}, args: { address: "Nonexistent Place" })

      expect(result[:success]).to be false
      expect(result[:message]).to include("not found")
    end

    it "rejects blank address" do
      expect { described_class.geocode(settings: {}, args: { address: "" }) }
        .to raise_error(ArgumentError, /empty/i)
    end

    it "handles rate limiting" do
      allow(http_double).to receive(:request).and_return(build_response(body: "", status: :rate_limit))

      result = described_class.geocode(settings: {}, args: { address: "Test" })

      expect(result[:success]).to be false
      expect(result[:message]).to include("failed")
    end

    it "handles HTTP errors" do
      allow(http_double).to receive(:request).and_return(build_response(body: "", status: :error))

      result = described_class.geocode(settings: {}, args: { address: "Test" })

      expect(result[:success]).to be false
    end

    it "handles invalid JSON" do
      allow(http_double).to receive(:request).and_return(
        build_response(body: "NOT_JSON")
      )

      result = described_class.geocode(settings: {}, args: { address: "Test" })

      expect(result[:success]).to be false
      expect(result[:message]).to include("failed")
    end

    it "handles connection timeout" do
      allow(http_double).to receive(:request).and_raise(Net::OpenTimeout.new("timed out"))

      result = described_class.geocode(settings: {}, args: { address: "Test" })

      expect(result[:success]).to be false
      expect(result[:message]).to include("failed")
    end

    it "passes lat/lng bounds when provided" do
      allow(http_double).to receive(:request).and_return(build_response(body: success_body))

      described_class.geocode(settings: {}, args: { address: "Test", lat: "-30.0", lng: "-51.0" })

      expect(http_double).to have_received(:request)
    end
  end

  describe ".distance" do
    let(:route_body) { '{"routes":[{"distance":1500,"duration":180}]}' }

    it "calculates distance between two addresses" do
      allow(http_double).to receive(:request).and_return(
        build_response(body: success_body),
        build_response(body: success_body),
        build_response(body: route_body)
      )

      result = described_class.distance(
        settings: {},
        args: { origin: "Addr A", destination: "Addr B" }
      )

      expect(result[:success]).to be true
      expect(result[:data][:meters]).to eq(1500)
      expect(result[:data][:km]).to eq(1.5)
      expect(result[:data][:duration_minutes]).to eq(3.0)
    end

    it "returns failure when route not found" do
      allow(http_double).to receive(:request).and_return(
        build_response(body: success_body),
        build_response(body: success_body),
        build_response(body: '{"routes":[]}')
      )

      result = described_class.distance(
        settings: {},
        args: { origin: "Addr A", destination: "Addr B" }
      )

      expect(result[:success]).to be false
      expect(result[:message]).to include("Route not found")
    end

    it "returns failure when response is nil" do
      allow(http_double).to receive(:request).and_return(
        build_response(body: success_body),
        build_response(body: success_body),
        build_response(body: 'null')
      )

      result = described_class.distance(
        settings: {},
        args: { origin: "Addr A", destination: "Addr B" }
      )

      expect(result[:success]).to be false
    end

    it "rejects blank origin or destination" do
      expect { described_class.distance(settings: {}, args: { origin: "", destination: "B" }) }
        .to raise_error(ArgumentError, /empty/i)
    end

    it "uses provided lat/lng directly for origin and destination" do
      allow(http_double).to receive(:request).and_return(build_response(body: route_body))

      result = described_class.distance(
        settings: {},
        args: { origin: "A", destination: "B", lat: "-30.0", lng: "-51.0" }
      )

      expect(result[:success]).to be true
    end
  end

  describe ".reverse_geocode" do
    let(:reverse_body) do
      '{"display_name":"Rua Test, Porto Alegre","lat":"-30.03","lon":"-51.21","address":{"city":"Porto Alegre","state":"RS","country":"BR"}}'
    end

    it "returns address for valid coordinates" do
      allow(http_double).to receive(:request).and_return(build_response(body: reverse_body))

      result = described_class.reverse_geocode(settings: {}, args: { lat: -30.03, lng: -51.21 })

      expect(result[:success]).to be true
      expect(result[:data][:city]).to eq("Porto Alegre")
    end

    it "returns failure when lat/lng missing" do
      result = described_class.reverse_geocode(settings: {}, args: {})

      expect(result[:success]).to be false
      expect(result[:message]).to include("lat/lng")
    end

    it "returns failure when response contains error" do
      allow(http_double).to receive(:request).and_return(
        build_response(body: '{"error":"Unable to geocode"}')
      )

      result = described_class.reverse_geocode(settings: {}, args: { lat: -30.03, lng: -51.21 })

      expect(result[:success]).to be false
    end

    it "returns failure when response is nil" do
      allow(http_double).to receive(:request).and_return(
        build_response(body: 'null')
      )

      result = described_class.reverse_geocode(settings: {}, args: { lat: -30.03, lng: -51.21 })

      expect(result[:success]).to be false
    end

    it "derives city from town when city is absent" do
      body = '{"display_name":"Rua Test","lat":"-30.03","lon":"-51.21","address":{"town":"Porto Alegre","state":"RS","country":"BR"}}'
      allow(http_double).to receive(:request).and_return(build_response(body: body))

      result = described_class.reverse_geocode(settings: {}, args: { lat: -30.03, lng: -51.21 })

      expect(result[:data][:city]).to eq("Porto Alegre")
    end
  end
end
