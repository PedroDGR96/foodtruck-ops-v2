class ProductAddonsController < AuthenticatedController
  before_action :set_group
  before_action :set_product_addon, only: %i[edit update destroy]

  def new
    authorize ProductAddon
    @product_addon = @product_addon_group.product_addons.build
  end

  def create
    authorize ProductAddon
    @product_addon = @product_addon_group.product_addons.build(product_addon_params)

    if @product_addon.save
      redirect_to product_path(@product_addon_group.product), notice: t("product_addons.created", name: @product_addon.name)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @product_addon
  end

  def update
    authorize @product_addon

    if @product_addon.update(product_addon_params)
      redirect_to product_path(@product_addon_group.product), notice: t("product_addons.updated", name: @product_addon.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @product_addon
    @product_addon.discard!

    redirect_to product_path(@product_addon_group.product), notice: t("product_addons.discarded", name: @product_addon.name)
  end

  private

  def set_group
    @product_addon_group = Current.business.product_addon_groups.find(params[:product_addon_group_id])
  end

  def set_product_addon
    @product_addon = @product_addon_group.product_addons.find(params[:id])
  end

  def product_addon_params
    params.require(:product_addon).permit(:name, :price, :active)
  end
end
