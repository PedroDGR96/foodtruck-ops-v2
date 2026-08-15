class CashRegistersController < AuthenticatedController
  before_action :set_register, only: %i[show close]

  def index
    authorize CashRegister
    @today = BusinessDay.window(Current.business)
    @current_shift = CashRegister.open.find_by(user: current_user)
    @registers = Current.business.cash_registers.includes(:user).order(opened_at: :desc).limit(30)
  end

  def show
    authorize @register
    @movement = @register.cash_movements.build
  end

  def new
    authorize CashRegister
    @register = CashRegister.new
  end

  def create
    authorize CashRegister
    register = CashRegister.new(user: current_user, opening_amount: opening_amount_param)
    CashRegisterService.open!(register: register, actor: current_user)
    redirect_to register, notice: t("cash_registers.opened")
  rescue ActiveRecord::RecordInvalid => e
    @register = e.record
    render :new, status: :unprocessable_entity
  end

  def close
    authorize @register, :close?
    CashRegisterService.close!(
      register: @register,
      actual_closing_amount: actual_closing_amount_param,
      actor: current_user
    )
    redirect_to @register, notice: t("cash_registers.closed")
  rescue CashRegister::ShiftError => e
    redirect_to @register, alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    @register = e.record
    @movement = @register.cash_movements.build
    render :show, status: :unprocessable_entity
  end

  private

  def set_register
    @register = Current.business.cash_registers.find(params[:id])
  end

  def opening_amount_param
    params.dig(:cash_register, :opening_amount).presence || 0
  end

  def actual_closing_amount_param
    params.dig(:cash_register, :actual_closing_amount)
  end
end
