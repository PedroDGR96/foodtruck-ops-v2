# app/controllers/daily_reports_controller.rb
class DailyReportsController < ApplicationController
  def show
    authorize DailyReport
    @report = DailyReport.call(Current.business, date_param)
  end

  private

  def date_param
    Date.parse(params[:date])
  rescue Date::Error, TypeError
    Date.current
  end
end
