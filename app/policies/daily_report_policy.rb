class DailyReportPolicy < ApplicationPolicy
  def show?
    owner?
  end
end
