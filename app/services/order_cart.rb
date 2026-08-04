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

  def initialize(order)
    @order = order
  end

  def add_item(product:, quantity: 1, variant: nil, addons: [])
    ensure_open_cart!
    ensure_same_business!(product, variant)

    quantity = [ quantity.to_i, 1 ].max
    addons = Array(addons)

    existing = if order.order_items.loaded?
        order.order_items.to_a.find { |item| item.product_id == product.id && item.product_variant_id == variant&.id }
    else
        order.order_items.find_by(product_id: product.id, product_variant_id: variant&.id)
    end
    if existing && addons.empty?
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
