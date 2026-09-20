# FoodTruck Ops 2.0 — Client-Demo Upgrade Roadmap

Status: IN PROGRESS (driven by the autonomous loop under PRIORITIES.md directives).
Companion runbook: `../DEMO.md` (the current 1.0 demo script).
This doc is the durable research + gap map; it lives in the epic main tree (NOT the
loop's patch target) so it survives context/internet loss and never collides with a
loop patch.

## Why 2.0 (the pitch)

The 1.0 demo is already strong: POS + cart, live Kitchen Display (KDS) over Turbo
Streams, deep variants/addons, a rich order lifecycle, cash drawer/shift with
reconciliation, LGPD compliance, Postgres RLS multi-tenancy, and a JSON:API surface.
What separates a *polished* demo from a *converting* one in 2026 are the operational
differentiators the market names most often for food trucks / quick-service:

| Research theme (2026 sources) | Where it lands in our product | Status today |
|---|---|---|
| Speed at the window (min taps) | POS flow | ✅ demo-ready |
| Kitchen Display / order routing | KDS | ✅ demo-ready |
| Modifiers / combos / variants | variants + addons | ✅ demo-ready |
| **Offline-mode resilience** | offline order queue | ❌ MISSING |
| **Location/route reporting** | revenue by stop + item-mix | ❌ MISSING (partial report) |
| **Inventory + low-stock alerts** | "86 an item before it sells out" | ❌ MISSING (bare stock column only) |
| **Loyalty / repeat-customer program** | stamp card / points / credits | ❌ MISSING |
| **Public QR / web ordering** | customer order-and-pay | ❌ MISSING (staff-only menu) |
| Cash drawer / shift reconcile | cash register module | ✅ demo-ready |
| Clear, live analytics dashboard | weekly + daily report | ⚠️ PARTIAL (no charts/drill-down) |
| Branded PWA (works "in the field") | manifest/service-worker | ⚠️ STOCK ("App" name) |
| Rich, realistic seed/demo data | demo-data.rb | ⚠️ THIN (3 products, 1 category) |

Note on offline: our own constraints (unreliable connectivity, tight budget) mirror
the food truck's. "Works offline / lost connection" is both a product feature and a
survivability story — worth being able to demo.

## Inventory / gap map (verified, read-only)

Already demo-ready: POS, KDS, modifiers, order lifecycle, cash drawer, LGPD, RLS,
JSON:API, RBAC (owner/cashier/kitchen).

Partial: CRM (basic history only — `CustomerHistory`), reporting (single `DailyReport`
+ home dashboard; no charts, no location concept), payments (mock gateway only),
PWA (stock template), i18n (pt-BR-first, en incomplete).

Missing (the real 2.0 builds): inventory w/ low-stock alerts, loyalty/rewards,
analytics by stop, public QR/web ordering, offline transaction queue.

Seed gap: `db/seeds.rb` creates only 1 business + 3 users; `bin/demo-data.rb` seeds
only 1 category, 3 products, 1 customer, an open shift and a few orders. No
variants/addons, no stock, no loyalty, no routes/stops in seed.

## Suggested 2.0 build order (each gate-verified, Tenancy-wrapped)

1. **Rich demo seed** (low risk, high demo value): extend `bin/demo-data.rb` with
   multiple categories, more products (with prices in BRL), variants + addon groups,
   customers with varied history, orders across every lifecycle state, an open shift
   with movements, and a couple of simulated "stops". Keep it idempotent (guarded by
   existing `gateway_reference`/`find_or_create` patterns).
2. **Inventory + low-stock alerts**: model stock that deducts on sale completion,
   a low-stock threshold with `available?`/`low_stock?` on products/variants, and a
   small owner-facing low-stock view. Demo: "this item will sell out — pull it."
3. **Analytics by stop/location**: add a lightweight `location`/`stop` on orders,
   then dashboard views that group revenue and item-mix by stop, with simple
   in-UI charts (no heavy libs), plus a date-filtered drill-down.
4. **Loyalty / repeat-customer**: points or stamp-card against customers, redeemable
   toward a discount at POS; customer history highlights repeat buyers.
5. **Public QR / web ordering**: a public (unauthenticated) menu under the tenant
   block that feeds orders into the same pipeline the staff POS uses; render a QR
   for the menu URL.
6. **Branded PWA + offline story**: rename/theme the manifest (`name: "FoodTruck Ops"`,
   icons, theme color), and — if it fits the gate — a local order queue that survives
   a dropped connection and syncs on reconnect.
7. **i18n completeness**: finish the `en` track so both locales are full (demo can
   switch language).

## Guardrails

- Every change keeps the gate green (rspec 0 failures; SimpleCov 95/95 overall +
  per-file). Do not silence per-file coverage.
- All tenant queries inside `Tenancy.with_business`; materialize lazy relations in
  the block (AGENTS.md).
- Never touch protected paths: `app/core/**`, `spec/rls/**`, `db/migrate/**`,
  `bin/**`, `docs/CORE_CONTRACT.md` — except the deliberate `bin/demo-data.rb` seed
  extension owned by ft-demo2.
- LGPD Phase 1 is DONE and the migration is applied — never re-apply it, never
  re-run `db-prepare` against an already-migrated DB (see the PG::DuplicateTable
  record in the loop notes).
- Findings mode unless the change is a mechanical, fully-verifiable fix.
