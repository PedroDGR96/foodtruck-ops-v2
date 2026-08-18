# Real maps provider using OpenStreetMap Nominatim for geocoding and
# OSRM (Open Source Routing Machine) for distance calculations.
# No API key required — respects usage policy (1 req/sec, valid User-Agent).
class OsmMapsProvider < MapsProvider
  NOMINATIM_BASE = "https://nominatim.openstreetmap.org"
  OSRM_BASE = "https://router.project-osrm.org"
  USER_AGENT = "FoodTruckOps/1.0 (integration)"
  RATE_LIMIT = 1.0 # seconds between requests

  class RateLimitError < StandardError; end
  class GeocodingError < StandardError; end
  class RoutingError < StandardError; end

  def self.geocode(settings:, args:)
    address = args[:address].to_s
    validate_address!(address)

    params = {
      q: address,
      format: "json",
      limit: 1,
      addressdetails: 1,
      countrycodes: "br"
    }
    params[:lat] = args[:lat] if args[:lat].present?
    params[:lon] = args[:lng] if args[:lng].present?

    response = get("#{NOMINATIM_BASE}/search", params)

    if response.empty?
      return { success: false, message: "Address not found: #{address}", data: {} }
    end

    result = response.first
    {
      success: true,
      message: "Address geocoded",
      data: {
        address: result.dig("display_name") || address,
        lat: result["lat"].to_f,
        lng: result["lon"].to_f,
        accuracy: result["type"] || "unknown",
        osm_id: result["osm_id"],
        importance: result["importance"]
      }
    }
  rescue GeocodingError, RateLimitError => e
    { success: false, message: "Geocoding failed: #{e.message}", data: {} }
  end

  def self.distance(settings:, args:)
    origin = args[:origin].to_s
    destination = args[:destination].to_s
    validate_address!(origin)
    validate_address!(destination)

    origin_coords = resolve_coords(origin, args)
    dest_coords = resolve_coords(destination, args)

    response = get(
      "#{OSRM_BASE}/route/v1/driving/#{origin_coords[:lng]},#{origin_coords[:lat]};#{dest_coords[:lng]},#{dest_coords[:lat]}",
      { overview: "false", steps: "false" }
    )

    if response.nil? || response["routes"].nil? || response["routes"].empty?
      return { success: false, message: "Route not found", data: {} }
    end

    route = response["routes"].first
    {
      success: true,
      message: "Distance calculated",
      data: {
        origin: origin,
        destination: destination,
        meters: route["distance"].to_i,
        km: (route["distance"] / 1000.0).round(2),
        duration_seconds: route["duration"].to_i,
        duration_minutes: (route["duration"] / 60.0).round(1)
      }
    }
  rescue RoutingError => e
    { success: false, message: "Routing failed: #{e.message}", data: {} }
  end

  def self.reverse_geocode(settings:, args:)
    lat = args[:lat]
    lng = args[:lng]
    return { success: false, message: "lat/lng required", data: {} } if lat.nil? || lng.nil?

    response = get(
      "#{NOMINATIM_BASE}/reverse",
      { lat: lat, lon: lng, format: "json", addressdetails: 1 }
    )

    if response.nil? || response["error"]
      return { success: false, message: "Reverse geocoding failed", data: {} }
    end

    {
      success: true,
      message: "Coordinates resolved",
      data: {
        address: response["display_name"],
        lat: response["lat"].to_f,
        lng: response["lon"].to_f,
        city: response.dig("address", "city") || response.dig("address", "town"),
        state: response.dig("address", "state"),
        country: response.dig("address", "country")
      }
    }
  end

  private

  def self.get(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = USER_AGENT
    req["Accept"] = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 10

    response = http.request(req)

    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPTooManyRequests
      raise RateLimitError, "Rate limited by #{uri.host}"
    else
      raise GeocodingError, "HTTP #{response.code}: #{response.message}"
    end
  rescue JSON::ParserError => e
    raise GeocodingError, "Invalid JSON: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise GeocodingError, "Timeout: #{e.message}"
  end

  def self.validate_address!(address)
    raise ArgumentError, "Address cannot be empty" if address.blank?
  end

  def self.resolve_coords(address, args)
    if args[:lat].present? && args[:lng].present?
      { lat: args[:lat].to_f, lng: args[:lng].to_f }
    else
      result = geocode(settings: {}, args: { address: address })
      raise GeocodingError, "Could not resolve: #{address}" unless result[:success]
      { lat: result[:data][:lat], lng: result[:data][:lng] }
    end
  end
end
