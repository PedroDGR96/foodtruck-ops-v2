class CategoriesController < AuthenticatedController
  before_action :set_category, only: %i[edit update destroy]

  def index
    authorize Category
    @categories = Current.business.categories.ordered
  end

  def new
    authorize Category
    @category = Category.new
  end

  def create
    authorize Category
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_path, notice: t("categories.created", name: @category.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @category
  end

  def update
    authorize @category

    if @category.update(category_params)
      redirect_to categories_path, notice: t("categories.updated", name: @category.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @category
    @category.discard!

    redirect_to categories_path, notice: t("categories.discarded", name: @category.name)
  end

  private

  def set_category
    @category = Current.business.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :position, :active)
  end
end
