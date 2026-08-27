class PrivacyIncident < ApplicationRecord
  include BusinessScoped

  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[detected investigating contained notified resolved].freeze
  ANPD_DEADLINE_HOURS = 48

  validates :title, presence: true
  validates :description, presence: true
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :detected_at, presence: true

  scope :open_incidents, -> { where.not(status: "resolved") }
  scope :critical, -> { where(severity: "critical").open_incidents }

  before_validation :set_detected_at, on: :create

  def anpd_notification_overdue?
    return false if anpd_notified_at.present?
    return false if anpd_notification_deadline.nil?

    anpd_notification_deadline < Time.current
  end

  def notify_anpd!(timestamp: Time.current)
    update!(anpd_notified_at: timestamp, status: "notified")
  end

  def notify_subjects!(timestamp: Time.current)
    update!(subjects_notified_at: timestamp)
  end

  def resolve!(notes: nil)
    update!(status: "resolved", remediation_notes: [ remediation_notes, notes ].compact.join("\n---\n"))
  end

  def contain!(notes: nil)
    update!(status: "contained", remediation_notes: [ remediation_notes, notes ].compact.join("\n---\n"))
  end

  private

  def set_detected_at
    self.detected_at ||= Time.current
    self.anpd_notification_deadline ||= detected_at + ANPD_DEADLINE_HOURS.hours
  end
end
