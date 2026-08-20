# Builds and edits a draft order's cart. Line items snapshot the product and
# variant names/prices at sale time so historical orders stay stable. A cart
# is locked once the order leaves the draft state.
class OrderCart
  class CartClosedError < StandardError; end

  def self.draft_for(user)
    Tenancy.with_business(user.business) do
      user.business.orders.draft.where(user: user).first_or_create!
    end
  end

  def self.add_item(order, product:, quantity: 1, variant: nil, addons: [])
    new(order).add_item(product: product, quantity: quantity, variant: variant, addons: addons)
  end

  def self.update_quantity(order, item_id, quantity)
    new(order).update_quantity(item_id, quantity)
  end

  def self.remove_item(order, item_id)
    new(order).remove_item(item_id)
  end

  def self.set_customer(order, customer:)
    new(order).set_customer(customer)
  end

  def self.quick_create_customer(order, attributes)
    new(order).quick_create_customer(attributes)
  end

  def self.clear_customer(order)
    new(order).clear_customer
  end

  def self.set_order_type(order, order_type, delivery_address_attributes: nil)
    new(order).set_order_type(order_type, delivery_address_attributes: delivery_address_attributes)
  end

  def initialize(order)
    @order = order
  end

  def add_item(product:, quantity: 1, variant: nil, addons: [])
    ensure_open_cart!
    ensure_same_business!(product, variant)

    quantity = [ quantity.to_i, 1 ].max
    addons = Array(addons)
    addon_ids = addons.map(&:id).to_set

    existing = find_existing_line(product, variant)
    if existing && same_addon_set?(existing, addon_ids)
      existing.update!(quantity: existing.quantity + quantity)
    else
      build_new_item(product, quantity, variant, addons)
    end

    order
  end

  def update_quantity(item_id, quantity)
    ensure_open_cart!
    item = find_item_in_cart(item_id)

    if quantity.to_i < 1
      item.destroy!
    else
      item.update!(quantity: quantity.to_i)
    end

    order
  end

  def remove_item(item_id)
    ensure_open_cart!
    find_item_in_cart(item_id).destroy!
    order
  end

  # Attaches an existing customer to the cart order.
  def set_customer(customer)
    ensure_open_cart!
    raise CartClosedError, "Cliente de outro estabelecimento" unless customer.business_id == order.business_id

    order.update!(customer: customer)
    order
  end

  # Builds a new customer from attributes (quick-create) and attaches it. The
  # business is assigned by BusinessScoped from the current tenant.
  def quick_create_customer(attributes)
    ensure_open_cart!
    customer = Customer.new(attributes)
    raise CartClosedError, "Cliente de outro estabelecimento" unless customer.business_id == order.business_id
    customer.save!
    order.update!(customer: customer)
    order
  end

  def clear_customer
    ensure_open_cart!
    order.update!(customer: nil)
    order
  end

  def set_order_type(order_type, delivery_address_attributes: nil)
    ensure_open_cart!

    if order_type == "delivery"
      raise CartClosedError, "Endereço de entrega obrigatório" if delivery_address_attributes.blank?

      order.build_delivery_address(delivery_address_attributes)
      order.delivery_fee = order.business.delivery_fee || 0
    else
      order.delivery_address&.mark_for_destruction
      order.delivery_fee = 0
    end

    order.order_type = order_type
    recompute_totals_in_memory
    order.save!
    order
  end

  def recompute_totals_in_memory
    order.order_item_addons.reload  # Ensure fresh data before recomputing totals
    items = order.order_items.reload
    addon_totals = order.order_item_addons.group(:order_item_id).sum(:price)
    new_subtotal = items.sum do |item|
      ((item.unit_price + addon_totals.fetch(item.id, 0.0)).round(2) * item.quantity).round(2)
    end.round(2)

    order.subtotal = new_subtotal
    order.total = (new_subtotal + order.tax + order.delivery_fee).round(2)
  end

  private

  attr_reader :order

  def ensure_open_cart!
    return if order.draft?

    raise CartClosedError, "A cart só pode ser alterada enquanto o pedido está em rascunho"
  end

  def find_item_in_cart(item_id)
    if order.order_items.loaded?
      order.order_items.to_a.find { |item| item.id == item_id } ||
        raise(ActiveRecord::RecordNotFound)
    else
      order.order_items.find(item_id)
    end
  end

  def find_existing_line(product, variant)
    if order.order_items.loaded?
      order.order_items.to_a.find { |item| item.product_id == product.id && item.product_variant_id == variant&.id }
    else
      order.order_items.find_by(product_id: product.id, product_variant_id: variant&.id)
    end
  end

  def same_addon_set?(item, addon_ids)
    item.order_item_addons.map(&:product_addon_id).to_set == addon_ids
  end

  def ensure_same_business!(product, variant)
    raise CartClosedError, "Produto de outro estabelecimento" unless product.business_id == order.business_id
    return unless variant && variant.product_id != product.id

    raise CartClosedError, "Variação não pertence ao produto"
  end

  def build_new_item(product, quantity, variant, addons)
    item = order.order_items.build(
      product: product,
      product_variant: variant,
      product_name: product.name,
      variant_name: variant&.name,
      unit_price: variant ? variant.effective_price : product.price,
      quantity: quantity
    )

    addons.each do |addon|
      item.order_item_addons.build(product_addon: addon, name: addon.name, price: addon.price)
    end

    item.save!
  end
end
