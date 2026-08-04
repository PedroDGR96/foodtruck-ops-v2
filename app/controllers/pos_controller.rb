class PosController < AuthenticatedController
  before_action :set_draft_order, only: %i[show add_item update_item remove_item confirm]

  def show
    authorize @draft_order, :create?
    @query = params[:query].to_s.strip
    @menu = MenuQuery.call(business: Current.business, query: @query)
  end

  def add_item
    authorize @draft_order, :update?
    product = Current.business.products.find(params[:product_id])
    variant = product.product_variants.find_by(id: params[:variant_id]) if params[:variant_id].present?
    addons = product.product_addons.where(id: params[:addon_ids])

    OrderCart.add_item(@draft_order, product: product, quantity: params[:quantity], variant: variant, addons: addons)
    redirect_to pos_path, notice: t("pos.added", name: product.name)
  rescue OrderCart::CartClosedError => e
    redirect_to pos_path, alert: e.message
  end

  def update_item
    authorize @draft_order, :update?
    OrderCart.update_quantity(@draft_order, params[:id], params[:quantity])
    redirect_to pos_path
  end

  def remove_item
    authorize @draft_order, :update?
    OrderCart.remove_item(@draft_order, params[:id])
    redirect_to pos_path
  end

  def confirm
    authorize @draft_order, :confirm?
    return redirect_to(pos_path, alert: t("pos.empty_cart")) if @draft_order.order_items.empty?

    OrderLifecycle.new(@draft_order, current_user).confirm!
    redirect_to new_order_payment_path(@draft_order), notice: t("orders.confirmed")
  end

  private

  def set_draft_order
    @draft_order = OrderCart.draft_for(current_user)
  end
end
