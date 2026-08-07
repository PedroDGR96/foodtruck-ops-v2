# Customer Module

Customer registry, quick-create from the POS, and purchase history.

## Purpose

- Manages customer profiles within a business
- Quick-create or attach a customer from the POS cart
- Computes purchase history from completed orders
- Soft-deletes inactive customers

## Key model

`Customer` (app/models/customer.rb) — includes `BusinessScoped` and `SoftDelete`.

**Fields:** `name` (required), `phone` (optional, unique per business among
non-deleted rows), `whatsapp`, `birthday`, `notes`, `discarded_at`.

**Associations:** belongs to `business`; has many `orders`.

**Unique constraint:** `(business_id, phone)` is unique only where
`phone IS NOT NULL AND discarded_at IS NULL`, so a phone number can be reused
after a customer is soft-deleted.

## Registration

Via the registry (`/customers`, owner/cashier) or from the POS cart:

```ruby
OrderCart.set_customer(order, customer: customer)
OrderCart.quick_create_customer(order, name: "João", phone: "11999887766")
OrderCart.clear_customer(order)
```

The POS path keeps the flow fast for walk-ins; `quick_create_customer` lets
`BusinessScoped` assign the tenant.

## Purchase history

`CustomerHistory.call(customer)` derives history from orders that "left the
cart" and were not cancelled/refunded (`Order.purchases` scope: not
`draft`/`cancelled`/`refunded`):

```ruby
history = CustomerHistory.call(customer)
history.order_count      # completed/paid/in-progress orders
history.total_spent      # sum of totals
history.average_spend    # total_spent / order_count
history.last_order       # most recent purchase
history.orders           # recent purchases
```

## Authorization

`CustomerPolicy`: index/show for all staff; create/update for owner/cashier;
destroy (soft delete) for owners only.

## Factories

```ruby
factory :customer do
  name { "João Silva" }
  phone { "11999887766" }
  business
end
```
