# FoodTruck-specific concerns that delegate to UniversalSaaS

module BusinessScoped
  def self.included(base)
    base.include UniversalSaaS::Concerns::TenantScoped
  end
end

module TenantChild
  def self.included(base)
    base.include UniversalSaaS::Concerns::TenantChild
  end
end

module SoftDelete
  def self.included(base)
    base.include UniversalSaaS::Concerns::SoftDelete
  end
end