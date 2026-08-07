# FoodTruck Ops — Documentation Index

Documentation for the Restaurant SaaS platform (Rails 8, Docker-only, pt-BR).
This set describes the code as merged to `main` (M1: tenancy, auth, menu,
POS/orders/payments, customers, audit). Features still in progress on feature
branches are explicitly marked as planned.

## Quick links

- [Setup](SETUP.md) — Docker dev loop: `bin/setup`, seeded users, health check
- [Deployment](DEPLOYMENT.md) — production image and `--profile prod`
- [Development](DEVELOPMENT.md) — architecture, tenancy layer, conventions
- [Tenancy](TENANCY.md) — RLS, `Tenancy.with_business`, `Current`, roles
- [Architecture](ARCHITECTURE.md) — component map, request flow, order lifecycle
- [Contributing](CONTRIBUTING.md) — code style, tests, commit policy
- [ERD](ERD.md) — database schema from `db/structure.sql`
- [Modules](MODULES/README.md) — per-module reference docs

## Status notes

- **API reference:** pending the JSON API ticket (T10, branch `t11-json-api`),
  which ships JSON:API + Swagger docs.
- **Planned modules** (separate branches, not on `main`): KDS, cash register,
  daily report, JSON API, integration adapters, delivery. See the module index
  and ticket branches for their current state.
