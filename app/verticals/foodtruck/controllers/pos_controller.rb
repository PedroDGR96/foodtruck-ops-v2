class PosController < AuthenticatedController
  before_action :set_draft_order, only: %i[show add_item update_item remove_item set_customer clear_customer confirm]
  before_action :require_open_shift, only: %i[confirm]

  def show
    authorize @draft_order, :create?
    @query = params[:query].to_s.strip
    @menu = MenuQuery.call(business: Current.business, query: @query, eager_load: false)
    @open_shift = CashRegister.open.find_by(user: current_user) if current_user.cashier? || current_user.owner?
    eager_load_cart_items
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
  rescue ActiveRecord::RecordNotFound
    redirect_to pos_path, alert: t("pos.product_not_found")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to pos_path, alert: e.record.errors.full_messages.to_sentence
  end

  def update_item
    authorize @draft_order, :update?
    OrderCart.update_quantity(@draft_order, params[:id], params[:quantity])
    redirect_to pos_path
  rescue OrderCart::CartClosedError => e
    redirect_to pos_path, alert: e.message
  rescue ActiveRecord::RecordNotFound
    redirect_to pos_path, alert: t("pos.item_not_found")
  end

  def remove_item
    authorize @draft_order, :update?
    OrderCart.remove_item(@draft_order, params[:id])
    redirect_to pos_path
  rescue OrderCart::CartClosedError => e
    redirect_to pos_path, alert: e.message
  rescue ActiveRecord::RecordNotFound
    redirect_to pos_path, alert: t("pos.item_not_found")
  end

  def set_customer
    authorize @draft_order, :update?

    if params[:customer_id].present?
      customer = Current.business.customers.find(params[:customer_id])
      OrderCart.set_customer(@draft_order, customer: customer)
      notice = t("pos.customer_attached", name: customer.name)
    else
      OrderCart.quick_create_customer(@draft_order, customer_params)
      notice = t("pos.customer_created", name: @draft_order.customer.name)
    end
    redirect_to pos_path, notice: notice
  rescue OrderCart::CartClosedError => e
    redirect_to pos_path, alert: e.message
  rescue ActiveRecord::RecordNotFound
    redirect_to pos_path, alert: t("pos.customer_not_found")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to pos_path, alert: e.record.errors.full_messages.to_sentence
  end

  def clear_customer
    authorize @draft_order, :update?
    OrderCart.clear_customer(@draft_order)
    redirect_to pos_path
  end

  def confirm
    authorize @draft_order, :confirm?
    return redirect_to(pos_path, alert: t("pos.empty_cart")) if @draft_order.order_items.empty?

    order_type = params.dig(:order, :order_type).presence || "local"
    OrderCart.set_order_type(@draft_order, order_type, delivery_address_attributes: delivery_address_params)

    OrderLifecycle.new(@draft_order, current_user).confirm!
    @draft_order.create_delivery! if @draft_order.delivery?
    redirect_to checkout_path(@draft_order), notice: t("orders.confirmed")
  rescue OrderCart::CartClosedError => e
    redirect_to pos_path, alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    redirect_to pos_path, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_draft_order
    @draft_order = OrderCart.draft_for(current_user)
  end

  def require_open_shift
    return if CashRegister.open.find_by(user: current_user)

    redirect_to pos_path, alert: t("pos.shift_required")
  end

  def eager_load_cart_items
    @draft_order = Current.business.orders.includes(order_items: :order_item_addons).find(@draft_order.id)
  end

  def customer_params
    params.require(:customer).permit(:name, :phone, :whatsapp, :birthday, :notes)
  end

  def delivery_address_params
    return nil unless params.dig(:order, :delivery_address).present?

    params.require(:order).require(:delivery_address).permit(
      :street, :number, :complement, :neighborhood, :city, :state, :zip, :reference
    )
  end
end
