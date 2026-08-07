# app/controllers/daily_reports_controller.rb
class DailyReportsController < ApplicationController
  before_action :set_daily_report, only: [:index]

  def index
    # Logic to fetch data respecting timezone and tenancy
    @report = DailyReportService.daily_report_for_business_day(current_user, Time.zone.now)
  end

  private

  def set_daily_report
    # Set the business day window based on the current time and TZ
    @start_time = Time.zone.now.beginning_of_day - (Time.zone.now.hour * 3600) # Simplified for example, actual logic depends on timezone rules
    @end_time = @start_time + 24.hours
  end
end