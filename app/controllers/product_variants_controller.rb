class ProductVariantsController < AuthenticatedController
  before_action :set_product
  before_action :set_product_variant, only: %i[edit update destroy]

  def new
    authorize ProductVariant
    @product_variant = @product.product_variants.build
  end

  def create
    authorize ProductVariant
    @product_variant = @product.product_variants.build(product_variant_params)

    if @product_variant.save
      redirect_to product_path(@product), notice: t("product_variants.created", name: @product_variant.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @product_variant
  end

  def update
    authorize @product_variant

    if @product_variant.update(product_variant_params)
      redirect_to product_path(@product), notice: t("product_variants.updated", name: @product_variant.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product_variant
    @product_variant.discard!

    redirect_to product_path(@product), notice: t("product_variants.discarded", name: @product_variant.name)
  end

  private

  def set_product
    @product = Current.business.products.find(params[:product_id])
  end

  def set_product_variant
    @product_variant = @product.product_variants.find(params[:id])
  end

  def product_variant_params
    params.require(:product_variant).permit(:name, :price, :stock, :active)
  end
end
