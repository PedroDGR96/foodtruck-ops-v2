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
    base = "rounded-md px-3 py-1.5 text-sm font-medium transition-colors duration-150"
    active ? "#{base} bg-brand-100 text-brand-700 dark:bg-brand-900/50 dark:text-brand-300" : "#{base} text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
  end

  def order_type_options
    Order.order_types.keys.map { |key| [ t("orders.order_types.#{key}"), key ] }
  end

  def order_status_badge_class(status)
    {
      draft: "badge-secondary", open: "badge-info", partially_paid: "badge-warning",
      paid: "badge-success", in_kitchen: "badge-info", ready: "badge-success",
      completed: "badge-success", cancelled: "badge-danger", refunded: "badge-danger",
      pending: "badge-secondary", in_progress: "badge-info", done: "badge-success"
    }.fetch(status.to_sym, "badge-secondary")
  end

  def payment_method_label(method)
    t("orders.payment_methods.#{method}")
  end
end
