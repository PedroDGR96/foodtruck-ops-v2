class AuditLog < ApplicationRecord
  include BusinessScoped

  validates :action, :resource, presence: true

  after_initialize :convert_metadata_keys_to_symbols

  def self.record!(action:, resource:, resource_id: nil, actor: nil, actor_id: nil, metadata: {})
    create!(
      action: action,
      resource: resource,
      resource_id: resource_id&.to_s || (resource.respond_to?(:id) ? resource.id.to_s : nil),
      actor_id: actor&.id || actor_id,
      metadata: metadata || {}
    )
  end

  private

  def convert_metadata_keys_to_symbols
    return unless metadata.is_a?(Hash) && metadata.keys.any? { |k| k.is_a?(String) }
    self.metadata = metadata.transform_keys(&:to_sym)
  end
end
