module Api
  module V1
    class ProductsController < BaseController
      before_action :set_product, only: %i[show update]

      def index
        authorize Product
        products = Current.business.products.ordered
        products = products.where(category_id: params[:category_id]) if params[:category_id].present?
        render_collection paginate(products)
      end

      def show
        authorize @product
        render_record @product
      end

      def create
        authorize Product
        require_writer!
        product = Current.business.products.new(product_params)
        product.save!
        render_record product, status: :created
      end

      def update
        authorize @product
        require_writer!
        @product.update!(product_params)
        render_record @product
      end

      private

      def set_product
        @product = Current.business.products.find(params[:id])
      end

      def product_params
        params.require(:product).permit(:name, :price, :category_id, :description, :status, :position)
      end
    end
  end
end
