class CreateLgpdComplianceTables < ActiveRecord::Migration[8.1]
  def change
    create_table :consent_records, id: :uuid do |t|
      t.references :business, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.string :data_subject_email
      t.string :consent_type, null: false
      t.string :consent_version, null: false
      t.string :consent_text_hash, null: false
      t.boolean :granted, null: false, default: true
      t.string :ip_address
      t.string :user_agent
      t.datetime :withdrawn_at
      t.timestamps
    end

    add_index :consent_records, %i[business_id data_subject_email consent_type], name: "idx_consent_records_on_biz_email_type"

    create_table :data_subject_requests, id: :uuid do |t|
      t.references :business, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.string :data_subject_email, null: false
      t.string :request_type, null: false
      t.string :status, null: false, default: "pending"
      t.text :description
      t.text :response_notes
      t.datetime :deadline_at, null: false
      t.datetime :completed_at
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :data_subject_requests, :deadline_at, where: "status = 'pending'", name: "idx_dsr_on_deadline_pending"

    create_table :privacy_incidents, id: :uuid do |t|
      t.references :business, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.string :severity, null: false, default: "low"
      t.string :status, null: false, default: "detected"
      t.text :affected_data_categories, array: true, default: []
      t.integer :affected_subjects_count, default: 0
      t.datetime :anpd_notified_at
      t.datetime :anpd_notification_deadline
      t.datetime :subjects_notified_at
      t.text :remediation_notes
      t.datetime :detected_at, null: false
      t.timestamps
    end
  end
end
