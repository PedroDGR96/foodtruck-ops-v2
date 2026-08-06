# Single source of truth for business-day boundaries. Shift and daily-report
# windows are always derived from the business timezone, never the server's:
# the "today" window is the calendar day in `businesses.timezone`, expressed as
# a UTC instant range.
class BusinessDay
  def self.window(business, date = nil)
    zone = ActiveSupport::TimeZone[business.timezone] || Time.zone
    day = date || Time.current.in_time_zone(zone).to_date
    start = zone.local(day.year, day.month, day.day)
    start...(start + 1.day)
  end
end
