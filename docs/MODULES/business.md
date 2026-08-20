# Business Module

The tenant root of the platform. Every tenant-scoped model belongs to exactly
one `Business`.

## Purpose

- Represents one restaurant/food truck (a tenant)
- Stores business configuration: currency, timezone, active flag, settings
- Anchors the `business_id` used by `BusinessScoped` and RLS
- Keeps a `menu_version` counter for menu cache invalidation

## Key model

`Business` (app/models/business.rb) — the root tenant model; it has **no**
`business_id` column and is **not** under RLS.

**Fields:** `name`, `currency` (default `BRL`), `timezone` (default
`America/Sao_Paulo`), `active` (default `true`), `settings` (jsonb),
`discarded_at` (soft delete), `menu_version` (integer, bumped by
`MenuInvalidatable`).

**Associations:** has many `users`, `categories`, `products`, `customers`,
`orders` (all `dependent: :restrict_with_exception`); through-associations for
`product_variants`, `product_addon_groups`, `product_addons`, `payments`.
`audit_logs` and `order_events` are scoped by `business_id` but not declared as
associations here.

## How the tenant is applied

1. `Tenancy.with_business(business)` sets `Current.business` and
   `SET LOCAL app.business_id` (see TENANCY.md).
2. Every tenant model includes `BusinessScoped`, default-scoping queries to
   `Current.business_id!` and assigning `business_id` on create.
3. PostgreSQL enforces `tenant_isolation` RLS policies keyed on the GUC for all
   tenant tables.

`Business` itself is reached unscoped — e.g. `Business.unscoped` where a menu
cache key needs the current `menu_version` regardless of tenant.

## Soft delete

`businesses.discarded_at` supports soft delete for the tenant root; the schema
keeps the row for audit/legal retention.

## Seeds

`db/seeds.rb` creates the `FoodTruck Ops` business and its owner/cashier/
kitchen users. It is idempotent and runs via `bin/db-prepare`.

## Notes

- `settings` is a free-form jsonb column; the menu version and timezone/currency
  are dedicated columns because they are load-bearing.
- New tenant-scoped tables should be generated with
  `bin/rails generate tenant_model <Name>` so they get the RLS/trigger treatment.
