# app/controllers/daily_reports_controller.rb
class DailyReportsController < ApplicationController
  before_action :set_daily_report, only: [ :show ]

  def show
    authorize :daily_report, :show?
  end

  private

  def set_daily_report
    @report = DailyReport.call(current_user.business, params[:date]&.to_date)
  end
end
