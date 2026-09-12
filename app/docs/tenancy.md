# Tenancy System Documentation

> **Status:** Production — Stable  
> **Last updated:** 2025-11-19  
> **Version:** 1.0.0

---

## Overview

The tenancy system enforces complete data isolation between businesses (food trucks) using a combination of PostgreSQL Row Level Security (RLS), default scopes, and application-level helpers. Every tenant table is RLS-gated on the `app.business_id` column, ensuring that queries without an active business context raise errors immediately.

---

## Architecture

### Core Components

| Component | Responsibility |
|-----------|---------------|
| PostgreSQL RLS | Enforces isolation at the database level — every tenant table has a policy gating access by `app.business_id` |
| `BusinessScoped` default scope | Adds `where(app: current_business)` to all tenant models automatically |
| `Tenancy.with_business(business)` | Context manager that sets the active business for the duration of the block |
| `ApplicationPolicy.role_helpers` | Pundit-style policies (`owner?`, `cashier?`, `kitchen?`, `staff?`) — delegate to role checks only, **never** compare `record.business_id` vs `user.business_id` |

### Data Model

Tenant tables (tables prefixed with `app.`) share a common schema:

```sql
-- Tenant-scoped models
- app.businesses
- app.users
- app.orders
- app.order_items
- app.payments
- app.order_carts
- app.products
- app.product_variants
- app.cash_registers
- app.cash_register_ledgers
- app.shifts
- app.kitchen_orders
```

All tenant tables have:
- `app_id` (integer, FK to `app.businesses.id`) — used by RLS policies
- `created_at`, `updated_at` timestamps

---

## RLS Configuration

### Policy Semantics

RLS policies are defined per-table but share the same semantics:

```sql
-- Example policy on app.orders
CREATE POLICY tenant_isolation ON app.orders FOR ALL
  USING (app_id = current_setting('app.business_id')::uuid);
```

The `current_setting('app.business_id')` GUC is set by `Tenancy.with_business(business)` before any query executes. If no business context exists, the setting returns NULL and all queries fail with:

> **Error:** `invalid input syntax for type uuid: ""`  
> This is expected — it means you are missing a `with_business` block.

### Default Scopes

Every tenant model includes `BusinessScoped`:

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  include BusinessScoped
end
```

`BusinessScoped` provides:

- A default scope that adds `where(app: current_business)` to all queries
- Automatic business_id inclusion in WHERE clauses
- Validation helpers (`valid?`, `save!`) that raise if the model is not scoped to an active tenant

---

## Usage Guidelines

### The Golden Rule

> **Every AR query on a tenant table must run inside `Tenancy.with_business(business) { ... }`.**

This applies to:
- Direct queries (`Order.where(...).first`)
- Relations loaded by associations (`order.payments.to_a`)
- Batch operations (`Order.where(status: :open).update_all(...)`)
- Custom scopes that materialize relations (`.resolve.to_a`, `.take`, etc.)

### Correct Pattern

```ruby
# ✅ CORRECT — business context is set before every query
Tenancy.with_business(current_user.business) do
  Order.where(status: :open).find_by(user_id: current_user.id)
end
```

### Incorrect Patterns

```ruby
# ❌ WRONG — no with_business, raises RLS error
Order.where(status: :open).first

# ❌ WRONG — relation materialized outside the block
Tenancy.with_business(current_user.business) do
  orders = Order.where(user_id: current_user.id)
end
orders.to_a # ← lazy load happens here, no business context → RLS error

# ❌ WRONG — comparing across tenants in policy
class OrderPolicy < ApplicationPolicy
  def show?
    record.app_id == user.business.app_id # NEVER compare record.business_id!
  end
end
```

### Materializing Relations Inside the Block

If you need to load a relation, do it **inside** the `with_business` block:

```ruby
Tenancy.with_business(current_user.business) do
  order = Order.find(order_id)
  # ✅ resolve.to_a is inside the block — safe
  items = order.order_items.resolve.to_a
end

# ❌ WRONG — .to_a called outside, relation loads without context
order = Tenancy.with_business(current_user.business).find(Order, order_id)
items = order.order_items.to_a # ← lazy load outside → RLS error
```

---

## Policies

### Pundit-Style Delegation

Policies in this project **do not** enforce tenant isolation. They delegate to `ApplicationPolicy.role_helpers` which check the user's role ONLY:

```ruby
# app/policies/order_policy.rb
class OrderPolicy < ApplicationPolicy
  # ✅ CORRECT — only checks role, never business_id comparison
  def show?
    owner? || cashier? || kitchen?
  end

  # ❌ NEVER write this:
  # def show?
  #   record.app_id == user.business.app_id # tenant isolation is RLS's job!
  # end
end
```

### Role Helpers

| Helper | Returns true when... |
|--------|---------------------|
| `owner?` | User has role `:owner` on the business |
| `cashier?` | User has role `:cashier` on the business |
| `kitchen?` | User has role `:kitchen` on the business |
| `staff?` | User has any staff-level role (excludes owner) |

These helpers are called by policies to determine access — they **do not** compare tenant IDs. Tenant isolation is enforced upstream by RLS + `BusinessScoped`.

---

## Common Pitfalls

### The Lazy-Load Trap

```ruby
# ❌ This raises: Postgres RLS uuid-empty error
Tenancy.with_business(business) do
  order = Order.find(order_id)
end
order.order_items.to_a # ← .to_a outside the block!
```

**Fix:** Materialize inside the block:

```ruby
Tenancy.with_business(business) do
  order = Order.find(order_id)
  items = order.order_items.resolve.to_a # ✅ inside the block
end
```

### The Policy Comparison Trap

Policies must **never** compare `record.business_id` to `user.business_id`. If you need tenant-aware authorization, use RLS policies instead:

```ruby
# ❌ WRONG — policy should not do this
class OrderPolicy < ApplicationPolicy
  def show?
    record.app_id == user.business.app_id # ← this is what triggers the gate failure
  end
end
```

---

## Testing Guidelines

### Factories

All factories wrap their own `with_business`:

```ruby
# spec/factories/orders.rb
FactoryBot.define do
  factory :order, class: "App::Order" do
    app { create(:business) }
    user { create(:user, business:) }
    # ...
  end
end
```

**Do NOT double-nest:** The factory already sets the context — your tests should not add another `with_business` around it.

### Assertions

Assert with tenant-aware expectations:

```ruby
# ✅ CORRECT
within_tenant { expect(Order.count).to eq(5) }

# ❌ WRONG
expect(Order.count).to eq(5) # ← no tenant context, RLS returns 0
```

---

## Troubleshooting

### "invalid input syntax for type uuid: \"\"" — Fix Me

This error means a query ran without an active business context. Check:
1. Is the query inside `Tenancy.with_business(business)`?
2. If loading a relation, is `.to_a` / `.resolve.to_a` called **inside** the block?
3. For factories — are they being used directly (which already wraps with_business)?

### "Policy denied access" — Wrong Service

If you see `OrderLifecycle::IllegalTransition` for a payment that should fail:
- The exception is raised by `OrderLifecycle#record_payment!`, NOT the policy
- Check the order status: only `open` / `partially_paid` orders accept payments
- The error message is localized pt-BR ("não pode exceder o saldo restante do pedido") — assert on `payment.errors[:amount]` or `raise_error(ActiveRecord::RecordInvalid)`

---

## Related Documentation

- [RLS Policies](./rls_policies.md) — detailed policy definitions
- [BusinessScoped](./business_scoped.md) — default scope implementation
- [Tenancy Context Manager](./tenancy_context.md) — `with_business` internals
- [ApplicationPolicy Roles](./application_policy_roles.md) — role helper implementations

---

## Quick Reference

| Task | Pattern |
|------|---------|
| Query a tenant table | `Tenancy.with_business(business) { Order.where(...) }` |
| Load an association | Materialize `.to_a` **inside** the block |
| Factory use | Use directly — already wraps with_business |
| Policy check | Delegate to role helpers only, no business_id comparison |
| Test assertion | Wrap in `within_tenant { ... }` |

---

## License

Internal foodtruck-ops-v2 documentation. Not for external distribution.
