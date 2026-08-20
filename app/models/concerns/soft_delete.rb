module SoftDelete
  extend ActiveSupport::Concern

  included do
    default_scope { where(discarded_at: nil) }
    scope :with_discarded, -> { unscope(where: :discarded_at) }
  end

  def discard!
    update!(discarded_at: Time.current)
  end

  def restore!
    update!(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end
end
