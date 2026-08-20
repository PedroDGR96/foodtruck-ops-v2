module BusinessScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :business

    default_scope { where(business_id: Current.business_id!) }
    before_validation :assign_current_business, on: :create
    validate :business_matches_current_business, on: :create
  end

  private

  def assign_current_business
    self.business_id ||= Current.business_id!
  end

  def business_matches_current_business
    return if business_id == Current.business_id!

    errors.add(:business_id, "must match the current business")
  end
end
