# Immutable audit record on the order timeline. Events are only ever appended
# by OrderLifecycle; rows are readonly once persisted.
class OrderEvent < ApplicationRecord
  include BusinessScoped

  belongs_to :order
  belongs_to :user, optional: true

  validates :event, presence: true
  validate :metadata_present

  after_find { readonly! }

  private

  def metadata_present
    errors.add(:metadata, :blank) if metadata.nil?
  end
end
