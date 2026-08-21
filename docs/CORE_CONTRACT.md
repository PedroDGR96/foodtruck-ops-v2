# Core Contract — vertical-agnostic boundary (Phase B1)

Status: **inventory proposal, no code moved yet** (B3 pending B2 decision).
Rule: a file enters core only when a non-restaurant business provably needs it.
Everything else stays vertical until the pilot vertical demands promotion.

## Tier 1 — CORE (proven generic)

| Area | Files |
| --- | --- |
| Tenancy & RLS | `app/core/lib/tenancy.rb`, `app/core/lib/tenancy/*` (runtime; `lib/tenancy/tenant_rls.rb` stays in `lib` as migration tooling), `app/core/models/concerns/business_scoped.rb`, `app/core/models/concerns/tenant_child.rb`, `app/core/models/current.rb`, `app/core/models/business.rb`, `app/core/jobs/application_job.rb`, `app/core/jobs/business_job.rb` |
| Identity & access | `app/models/user.rb`, `app/models/token.rb`, `app/controllers/application_controller.rb`, `app/controllers/authenticated_controller.rb`, `app/controllers/users/*`, `app/controllers/users_controller.rb` |
| Order lifecycle shell | `app/models/order_event.rb`, `app/services/order_lifecycle.rb`, `app/services/order_service.rb`, `app/controllers/orders_controller.rb` (state machine, events, cancellation/refund flow) |
| Payments | `app/models/payment.rb`, `app/controllers/order_payment_controller.rb` |
| Audit | `app/models/audit_log.rb` |
| Business calendar & reporting | `app/services/business_day.rb`, `app/services/daily_report.rb`, `app/controllers/daily_reports_controller.rb` |
| Generic concerns | `app/core/models/concerns/soft_delete.rb` |

## Tier 2 — VERTICAL (restaurant skin; stays put in B3)

Catalog/menu (`product*`, `category`, `menu_*`, `product_addon*`, `menu_query`,
`menu_invalidatable`, products/categories/menu/addons controllers), kitchen
(`kitchen_controller` + kitchen scopes), delivery (`delivery.rb`,
`delivery_address.rb`), POS (`pos_controller`), cash operations
(`cash_register*`, `cash_movement*` — retail till concept), integrations
(`integration_setting*`, `lib/adapter_registry`, integrations_controller),
customers (`customer.rb`, `customer_history.rb`, customers_controller —
see open questions).

## Known entanglements to resolve during B3 (each = its own directive)

1. **`order.rb` is core-shaped but vertically polluted**: `kitchen_status`
   enum, `has_one :delivery/:delivery_address`, `order_type`
   local/delivery/pickup, `active` scope references `in_kitchen`. Plan:
   slim core order to status/payment/audit surface; move kitchen/delivery
   fields behind vertical extensions.
2. **`order_item.rb` belongs_to product** — line items must reference an
   abstract "line" or polymorphic sellable before they can go core.
3. **`daily_report.rb` aggregates by product/method** — needs a
   vertical-supplied breakdown hook to be fully core.
4. **Pundit policies mirror controllers** — each move takes its policies.

## Open questions (decide at B2 / medical pilot)

- Customers: patients≈customers → likely core, but conservative route keeps
  it vertical until the second vertical proves shape parity.
- Cash register: any till-based business vs clinic online payments —
  default vertical.
- Adapter registry: payment-gateway abstraction could be core
  infrastructure; audit its interface before deciding.

## Rules for the boundary (the fence)

- Vertical code may depend on core; core NEVER depends on vertical
  (no constantize into menu/product/delivery from core files).
- Every extraction step: one area per commit, specs move with code,
  full bin/ci green, git tag `core-step-N` before each move.
- Anything not listed here is vertical by default.
