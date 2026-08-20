module Api
  module V1
    class CategoriesController < BaseController
      before_action :set_category, only: %i[show update]

      def index
        authorize Category
        render_collection paginate(Current.business.categories.ordered)
      end

      def show
        authorize @category
        render_record @category
      end

      def create
        authorize Category
        require_writer!
        category = Current.business.categories.new(category_params)
        category.save!
        render_record category, status: :created
      end

      def update
        authorize @category
        require_writer!
        @category.update!(category_params)
        render_record @category
      end

      private

      def set_category
        @category = Current.business.categories.find(params[:id])
      end

      def category_params
        params.require(:category).permit(:name, :position, :active)
      end
    end
  end
end
