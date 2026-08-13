# Contract for marketplace providers handling order intake and management
# (iFood, 99Food and similar platforms).
class MarketplaceProvider
  def self.create_order(settings:, args:)
    raise NotImplementedError
  end

  def self.update_order(settings:, args:)
    raise NotImplementedError
  end

  def self.cancel_order(settings:, args:)
    raise NotImplementedError
  end
end
