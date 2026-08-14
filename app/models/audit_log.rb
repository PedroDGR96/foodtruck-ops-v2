class AuditLog < ApplicationRecord
  include BusinessScoped

  validates :action, :resource, presence: true

  def self.record!(action:, resource:, resource_id: nil, actor: nil, actor_id: nil, metadata: {})
    create!(
      action: action,
      resource: resource,
      resource_id: resource_id&.to_s || (resource.respond_to?(:id) ? resource.id.to_s : nil),
      actor_id: actor&.id || actor_id,
      metadata: metadata || {}
    )
  end
end
