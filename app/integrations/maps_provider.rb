# Contract for maps providers (geocoding and distance calculation).
class MapsProvider
  def self.geocode(settings:, args:)
    raise NotImplementedError
  end

  def self.test_connection(settings:)
    raise NotImplementedError
  end

  def self.distance(settings:, args:)
    raise NotImplementedError
  end
end
