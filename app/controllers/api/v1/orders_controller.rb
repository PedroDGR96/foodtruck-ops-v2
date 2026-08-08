module Api
  module V1
    class OrdersController < BaseController
      before_action :set_order, only: %i[show cancel force_cancel refund]

      def index
        authorize Order
        render_collection paginate(Current.business.orders.recent)
      end

      def show
        authorize @order
        render_record @order
      end

      def create
        authorize Order
        require_writer!
        order = Current.business.orders.new(order_attributes)
        OrderLifecycle.new(order, current_user).confirm!
        render_record order, status: :created
      end

      def cancel
        authorize @order, :cancel?
        require_writer!
        OrderLifecycle.new(@order, current_user).cancel!
        render_record @order
      end

      def force_cancel
        authorize @order, :cancel?
        require_writer!
        OrderLifecycle.new(@order, current_user).cancel!(force: true)
        render_record @order
      end

      def refund
        authorize @order, :refund?
        require_writer!
        OrderLifecycle.new(@order, current_user).refund!
        render_record @order
      end

      private

      def set_order
        @order = Current.business.orders.find(params[:id])
      end

      def order_attributes
        attrs = params.require(:order).permit(:order_type, :notes, :customer_id, :user_id, :subtotal, :tax, :delivery_fee, :total)
        attrs[:subtotal] ||= 0
        attrs[:tax] ||= 0
        attrs[:delivery_fee] ||= 0
        attrs[:total] ||= (attrs[:subtotal].to_f + attrs[:tax].to_f + attrs[:delivery_fee].to_f).round(2)
        attrs
      end
    end
  end
end
