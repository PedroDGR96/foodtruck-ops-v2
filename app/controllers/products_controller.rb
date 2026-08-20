class ProductsController < AuthenticatedController
  before_action :set_product, only: %i[show edit update destroy]

  def index
    authorize Product
    @products = Current.business.products.includes(:category).ordered
  end

  def show
    authorize @product
    @product_variants = @product.product_variants.ordered
    @product_addon_groups = @product.product_addon_groups.ordered
  end

  def new
    authorize Product
    @product = Product.new(category_id: params[:category_id])
  end

  def create
    authorize Product
    @product = Product.new(product_params)

    if @product.save
      redirect_to product_path(@product), notice: t("products.created", name: @product.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @product
  end

  def update
    authorize @product

    if @product.update(product_params)
      redirect_to product_path(@product), notice: t("products.updated", name: @product.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product
    @product.discard!

    redirect_to products_path, notice: t("products.discarded", name: @product.name)
  end

  private

  def set_product
    @product = Current.business.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price, :status, :position, :category_id, :image)
  end
end
