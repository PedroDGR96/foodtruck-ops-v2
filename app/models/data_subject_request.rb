class DataSubjectRequest < ApplicationRecord
  include BusinessScoped

  belongs_to :user, optional: true

  REQUEST_TYPES = %w[access correction deletion portability revocation].freeze
  STATUSES = %w[pending in_progress completed rejected].freeze
  LGPD_DEADLINE_DAYS = 15

  validates :data_subject_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :overdue, -> { pending.where("deadline_at < ?", Time.current) }
  scope :due_soon, -> { pending.where("deadline_at BETWEEN ? AND ?", Time.current, LGPD_DEADLINE_DAYS.days.from_now) }

  before_create :set_deadline

  def overdue?
    deadline_at < Time.current && status == "pending"
  end

  def days_remaining
    (deadline_at.to_date - Date.current).to_i
  end

  def complete!(notes: nil)
    update!(status: "completed", completed_at: Time.current, response_notes: notes)
  end

  def reject!(notes: nil)
    update!(status: "rejected", completed_at: Time.current, response_notes: notes)
  end

  def start_progress!
    update!(status: "in_progress") if status == "pending"
  end

  private

  def set_deadline
    self.deadline_at ||= LGPD_DEADLINE_DAYS.days.from_now
  end
end
