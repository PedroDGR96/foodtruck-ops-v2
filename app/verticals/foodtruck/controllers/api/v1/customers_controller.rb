module Api
  module V1
    class CustomersController < BaseController
      before_action :set_customer, only: %i[show update]

      def index
        authorize Customer
        render_collection paginate(Current.business.customers.ordered)
      end

      def show
        authorize @customer
        render_record @customer
      end

      def create
        authorize Customer
        require_writer!
        customer = Current.business.customers.new(customer_params)
        if customer.save
          render_record customer, status: :created
        else
          render json: { errors: customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @customer
        require_writer!
        if @customer.update(customer_params)
          render_record @customer
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_customer
        @customer = Current.business.customers.find(params[:id])
      end

      def customer_params
        params.require(:customer).permit(:name, :phone, :whatsapp, :birthday, :notes)
      end
    end
  end
end
