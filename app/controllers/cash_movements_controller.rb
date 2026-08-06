class CashMovementsController < AuthenticatedController
  before_action :set_register

  def create
    authorize @register, :record_movement?
    CashRegisterService.record_movement!(
      register: @register,
      movement_type: movement_params[:movement_type],
      category: movement_params[:category],
      amount: movement_params[:amount],
      reason: movement_params[:reason],
      actor: current_user
    )
    redirect_to @register, notice: t("cash_registers.movement_recorded")
  rescue ActiveRecord::RecordInvalid => e
    @movement = e.record
    render "cash_registers/show", status: :unprocessable_entity
  end

  private

  def set_register
    @register = Current.business.cash_registers.find(params[:cash_register_id])
  end

  def movement_params
    params.require(:cash_movement).permit(:movement_type, :category, :amount, :reason)
  end
end
