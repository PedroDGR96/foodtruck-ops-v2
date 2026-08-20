class Current < ActiveSupport::CurrentAttributes
  attribute :business

  def business_id
    business&.id
  end

  def business_id!
    business_id || raise(Tenancy::TenantNotSetError, "No current business has been set")
  end
end
