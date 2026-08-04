class PaymentsController < AuthenticatedController
  before_action :set_order

  def new
    authorize @order, :pay?
    @payment = @order.payments.build
  end

  def create
    authorize @order, :pay?
    payment = @order.payments.build(payment_params)
    OrderLifecycle.new(@order, current_user).record_payment!(payment)

    if @order.paid?
      redirect_to order_path(@order), notice: t("orders.paid")
    else
      redirect_to new_order_payment_path(@order), notice: t("orders.partial_payment")
    end
  rescue ActiveRecord::RecordInvalid => e
    @payment = e.record
    render :new, status: :unprocessable_entity
  end

  private

  def set_order
    @order = Current.business.orders.find(params[:order_id])
  end

  def payment_params
    params.require(:payment).permit(:method, :amount, :gateway_reference)
  end
end
