module Tenancy
  class TenantNotSetError < StandardError; end

  module_function

  def with_business(business_or_id)
    business_id = business_or_id.respond_to?(:id) ? business_or_id.id : business_or_id
    raise TenantNotSetError, "A business is required for tenant-scoped work" if business_id.blank?

    business = business_or_id.respond_to?(:id) ? business_or_id : Business.find(business_id)
    raise TenantNotSetError, "Business not found" unless business.present?

    result = nil
    rethrow = false
    caught = nil
    Current.set(business: business) do
      ActiveRecord::Base.transaction(requires_new: true) do
        previous = current_business_id
        begin
          set_local!(business_id)
          caught = catch(:warden) do
            result = yield
            rethrow = true
            nil
          end
        ensure
          restore_business_id(previous)
        end
      end
      throw :warden, caught unless rethrow
    end
    result
  end

  def current_business_id
    ActiveRecord::Base.connection.select_value("SELECT current_setting('app.business_id', true)")
  end

  def set_local!(business_id)
    quoted_id = ActiveRecord::Base.connection.quote(business_id)
    ActiveRecord::Base.connection.execute("SET LOCAL app.business_id = #{quoted_id}")
  end

  def restore_business_id(previous)
    if previous && !previous.blank?
      set_local!(previous)
    else
      reset_local!
    end
  end

  def reset_local!
    ActiveRecord::Base.connection.execute("RESET app.business_id")
  end
end
