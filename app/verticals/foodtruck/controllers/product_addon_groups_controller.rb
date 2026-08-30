class ProductAddonGroupsController < AuthenticatedController
  before_action :set_product
  before_action :set_group, only: %i[edit update destroy]

  def new
    authorize ProductAddonGroup
    @product_addon_group = @product.product_addon_groups.build
  end

  def create
    authorize ProductAddonGroup
    @product_addon_group = @product.product_addon_groups.build(product_addon_group_params)

    if @product_addon_group.save
      redirect_to product_path(@product), notice: t("product_addon_groups.created", name: @product_addon_group.name)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @product_addon_group
  end

  def update
    authorize @product_addon_group

    if @product_addon_group.update(product_addon_group_params)
      redirect_to product_path(@product), notice: t("product_addon_groups.updated", name: @product_addon_group.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @product_addon_group
    @product_addon_group.discard!

    redirect_to product_path(@product), notice: t("product_addon_groups.discarded", name: @product_addon_group.name)
  end

  private

  def set_product
    @product = Current.business.products.find(params[:product_id])
  end

  def set_group
    @product_addon_group = @product.product_addon_groups.find(params[:id])
  end

  def product_addon_group_params
    params.require(:product_addon_group).permit(:name, :multiple, :min_select, :max_select, :position, :active)
  end
end
