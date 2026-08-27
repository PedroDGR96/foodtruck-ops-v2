class ConsentRecord < ApplicationRecord
  include BusinessScoped

  belongs_to :user, optional: true

  validates :consent_type, presence: true, inclusion: { in: %w[privacy_policy marketing analytics] }
  validates :consent_version, presence: true
  validates :consent_text_hash, presence: true
  validates :data_subject_email, presence: true, if: -> { user_id.blank? }
  validates :data_subject_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(granted: true, withdrawn_at: nil) }
  scope :for_email, ->(email) { where(data_subject_email: email) }

  def withdrawn?
    withdrawn_at.present?
  end

  def withdraw!(timestamp: Time.current)
    update!(granted: false, withdrawn_at: timestamp)
  end

  def self.latest_for(email, type)
    for_email(email).where(consent_type: type).order(created_at: :desc).first
  end

  def self.granted?(email, type)
    record = latest_for(email, type)
    record&.granted? && !record.withdrawn?
  end
end
