module TenantChild
  extend ActiveSupport::Concern

  class_methods do
    # Validates that a belongs_to parent belongs to the same business, so the
    # child can never be attached to another tenant's record.
    def validates_parent_business_for(*attributes)
      validate do
        attributes.each do |attribute|
          parent = public_send(attribute)
          next if parent.nil? || parent.business_id == business_id

          errors.add(attribute, :invalid)
        end
      end
    end
  end
end
