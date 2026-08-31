class KitchenController < AuthenticatedController
  before_action :set_order, only: %i[start done]

  def show
    authorize :kitchen, :show?
    @orders = Current.business.orders.kitchen_queue.limit(100)
    @completed = Current.business.orders.kitchen_completed.limit(50)
  end

  def start
    authorize @order, :start_cooking?
    OrderLifecycle.new(@order, current_user).start_cooking!
    redirect_back fallback_location: kitchen_path, notice: t("kitchen.started")
  rescue OrderLifecycle::IllegalTransition
    redirect_back fallback_location: kitchen_path, alert: t("kitchen.cannot_start")
  end

  def done
    authorize @order, :mark_ready?
    OrderLifecycle.new(@order, current_user).mark_ready!
    redirect_back fallback_location: kitchen_path, notice: t("kitchen.ready")
  rescue OrderLifecycle::IllegalTransition
    redirect_back fallback_location: kitchen_path, alert: t("kitchen.cannot_ready")
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:id])
  end
end
