module MenuInvalidatable
  extend ActiveSupport::Concern

  included do
    after_commit :bump_menu_version
  end

  private

  def bump_menu_version
    return unless business_id

    Business.unscoped.where(id: business_id).update_all("menu_version = menu_version + 1")
  end
end
