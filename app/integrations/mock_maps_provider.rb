# Deterministic, stateless mock for MapsProvider. Coordinates and distances are
# derived from the input strings (via a stable CRC32) so the same request
# always yields the same response.
class MockMapsProvider < MapsProvider
  def self.geocode(settings:, args:)
    address = args[:address].to_s
    validate!(address)

    if args[:lat].present? && args[:lng].present?
      lat = args[:lat].to_f.round(6)
      lng = args[:lng].to_f.round(6)
    else
      lat, lng = deterministic_coordinates(address)
    end

    {
      success: true,
      message: "Address '#{address}' geocoded",
      data: {
        address: address,
        lat: lat,
        lng: lng,
        accuracy: args[:accuracy] || "rooftop"
      }
    }
  end

  def self.distance(settings:, args:)
    origin = args[:origin].to_s
    destination = args[:destination].to_s
    validate!(origin)
    validate!(destination)

    meters = 500 + (Zlib.crc32("#{origin}->#{destination}") % 9_500)
    {
      success: true,
      message: "Distance calculated between '#{origin}' and '#{destination}'",
      data: {
        origin: origin,
        destination: destination,
        meters: meters,
        km: (meters / 1000.0).round(2)
      }
    }
  end

  def self.deterministic_coordinates(address)
    hash = Zlib.crc32(address)
    lat = (-90 + (hash % 18_000) / 100.0).round(6)
    lng = (-180 + ((hash >> 1) % 36_000) / 100.0).round(6)
    [ lat, lng ]
  end
  private_class_method :deterministic_coordinates

  def self.validate!(value)
    raise ArgumentError, "Address cannot be empty" if value.empty?
  end
  private_class_method :validate!
end
