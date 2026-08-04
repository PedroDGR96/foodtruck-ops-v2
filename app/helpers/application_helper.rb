module ApplicationHelper
  def format_money(amount)
    number_to_currency(amount, locale: :"pt-BR")
  end

  def format_datetime(datetime)
    return nil unless datetime

    Time.use_zone(business_timezone) { I18n.l(datetime.in_time_zone, format: :br) }
  end

  def format_date(date)
    return nil unless date

    Time.use_zone(business_timezone) { I18n.l(date.to_date, format: :short_br) }
  end

  def business_timezone
    Current.business&.timezone.presence || Rails.application.config.time_zone || "UTC"
  end

  def nav_link_class(active)
    base = "rounded-md px-3 py-1.5 text-sm font-medium"
    active ? "#{base} bg-brand-50 text-brand-700 dark:bg-brand-950 dark:text-brand-300" : "#{base} text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
  end
end
