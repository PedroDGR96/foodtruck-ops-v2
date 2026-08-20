# Contract for marketplace providers handling order intake and management
# (iFood, 99Food, Rappi and similar platforms). Subclasses implement the
# actual API integration; the mock provides deterministic sandbox behavior.
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

  def self.status(settings:, args:)
    raise NotImplementedError
  end

  def self.webhook_verify(settings:, args:)
    raise NotImplementedError
  end
end
