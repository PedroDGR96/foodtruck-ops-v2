module Api
  module V1
    class CashRegistersController < BaseController
      before_action :set_cash_register, only: %i[show close]

      def index
        authorize CashRegister
        render_collection paginate(Current.business.cash_registers.order(opened_at: :desc))
      end

      def show
        authorize @cash_register
        render_record @cash_register
      end

      def create
        authorize CashRegister
        require_writer!
        register = Current.business.cash_registers.new(cash_register_params)
        register.user ||= current_user
        register.save!
        render_record register, status: :created
      end

      def close
        authorize @cash_register, :close?
        require_writer!
        @cash_register.close!(actual_closing_amount: params[:actual_closing_amount], actor: current_user)
        render_record @cash_register
      end

      def active
        authorize CashRegister, :show?
        register = Current.business.cash_registers.open.order(opened_at: :desc).first
        return render_not_found(ActiveRecord::RecordNotFound.new) unless register

        render_record register
      end

      private

      def set_cash_register
        @cash_register = Current.business.cash_registers.find(params[:id])
      end

      def cash_register_params
        params.require(:cash_register).permit(:opening_amount)
      end
    end
  end
end
