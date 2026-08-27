class ComplianceDashboardController < AuthenticatedController
  def show
    authorize :compliance, :show?

    @consent_stats = {
      total: ConsentRecord.count,
      active: ConsentRecord.active.count,
      withdrawn: ConsentRecord.where.not(withdrawn_at: nil).count
    }
    @dsar_stats = {
      pending: DataSubjectRequest.pending.count,
      overdue: DataSubjectRequest.overdue.count,
      due_soon: DataSubjectRequest.due_soon.count,
      completed: DataSubjectRequest.where(status: "completed").count
    }
    @incident_stats = {
      open: PrivacyIncident.open_incidents.count,
      critical: PrivacyIncident.critical.count,
      anpd_overdue: PrivacyIncident.open_incidents.count { |i| i.anpd_notification_overdue? }
    }
    @recent_dsars = DataSubjectRequest.order(created_at: :desc).limit(5)
    @recent_incidents = PrivacyIncident.order(detected_at: :desc).limit(5)
  end
end
