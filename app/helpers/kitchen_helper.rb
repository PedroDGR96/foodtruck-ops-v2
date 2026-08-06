module KitchenHelper
  OVERDUE_THRESHOLD = 15.minutes

  # Seconds the order has been in the kitchen, used for the server-rendered
  # initial prep timer. The live count-up lives in kitchen_timer_controller.
  def kitchen_prep_elapsed(order)
    started = order.started_at || order.created_at
    [ (Time.current - started).to_i, 0 ].max
  end

  def kitchen_overdue_threshold
    OVERDUE_THRESHOLD.to_i
  end

  def kitchen_overdue?(order)
    kitchen_prep_elapsed(order) >= kitchen_overdue_threshold
  end

  def kitchen_prep_badge_class(order)
    kitchen_overdue?(order) ? "badge-danger" : "badge-info"
  end

  def format_prep_time(seconds)
    "%d:%02d" % [ seconds / 60, seconds % 60 ]
  end
end
