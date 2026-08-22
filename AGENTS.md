# AGENTS.md — foodtruck-ops (t12-mock-adapters)

Run everything through the compose stack mounted at the repo root. The app image
is built on first `run`; subsequent runs hit the cache and are fast.

## Run the test suite
```bash
docker compose --profile test run --rm \
  -e DATABASE_URL=postgresql://app:app@db:5432/foodtruck_ops_test \
  -e RAILS_ENV=test \
  test bundle exec rspec
```
- The DB lives in the `db` service (`postgres:17`); it's healthy within `~3s` after `up`.
- The app role needs `CONNECT` on the test DB (granted by `bin/ci`); if a fresh DB is used, run
  `docker compose run --rm --no-deps -e DATABASE_URL=postgresql://migrator:migrator@db:5432/foodtruck_ops_test test bin/db-prepare`
  then `psql "$DATABASE_URL" -c "GRANT CONNECT ON DATABASE foodtruck_ops_test TO app;"`.
- DB roles: runtime = `app` (unprivileged); migrations/seeds/grants = `migrator`
  (no superuser, no BYPASSRLS); `dbadmin` is break-glass; bootstrap `app_owner`
  stays idle. Never use a superuser for routine operations.
- Protected security fences — do not modify or weaken: `spec/rls/`,
  `spec/i18n/completeness_spec.rb`, `spec/core/`, `docker/postgres/`,
  `bin/db-demote-owner`, `bin/ci`. They enforce CIS controls (FORCE RLS on
  tenant tables, no-superuser posture, i18n completeness) and fail CI loudly.

## Run the full CI gate (lint + security + tests + coverage)
```bash
bin/ci
```
Equivalent to, in order: `rubocop`, `brakeman --no-pager`, `rspec`.
The pass bar is **rspec 0 failures** AND **SimpleCov `minimum 95` / `minimum_per_file 95`** (overall + per-file).
`bin/ci` uses `foodtruck_ops_test_t13`; the compose `test` service defaults to `foodtruck_ops_test`.

## Local checks only
```bash
# type/check style (fast, no DB)
docker compose --profile test run --rm -e RAILS_ENV=test test bundle exec rubocop
docker compose --profile test run --rm -e RAILS_ENV=test test bundle exec brakeman --no-pager
```

## ⚠️ Critical project constraint — tenancy & RLS
Tenant isolation is **Postgres RLS**, not AR scopes alone. Every tenant table has:
```sql
CREATE POLICY tenant_isolation ON <t>
  USING (business_id = current_setting('app.business_id')::uuid)
  WITH CHECK (business_id = current_setting('app.business_id')::uuid);
```
- The GUC `app.business_id` is set only inside `Tenancy.with_business(business).{ do ... }`
  (`lib/tenancy.rb`). It does `SET LOCAL app.business_id = <id>` and `RESET`s on exit.
- `BusinessScoped` (`app/models/concerns/business_scoped.rb`) adds a default scope
  `where(business_id: Current.business_id!)` — `Current.business_id!` **raises** if unset.
- **Never run AR queries or raw SQL on tenant tables outside `with_business`.** If you do, the
  RLS policy evaluates `current_setting('app.business_id')::uuid` against an empty/unset GUC and
  PostgreSQL raises `PG::InvalidTextRepresentation: ERROR: invalid input syntax for type uuid: ""`.
- Production entry points are covered: a per-request tenant block (see
  `config/initializers/auth_audit.rb`) + Sidekiq `Tenancy` middleware
  (`lib/tenancy/sidekiq_server_middleware.rb`). Background/console callers must wrap in
  `Tenancy.with_business(...)`.
- If a service returns a hash holding a lazy `ActiveRecord::Relation` (e.g. `DailyReport#shifts`),
  materialize it (`.to_a`) inside the tenant block — a relation read outside `with_business`
  triggers the same `uuid: ""` error.

## Test data
- Use FactoryBot factories in `spec/factories/*`. Many factories define a custom `to_create` that
  nests `Tenancy.with_business(record.business) { record.save! }` — do not duplicate that nesting
  in specs; just `create(:thing, business: business)` inside your own `with_business`.
- `use_transactional_fixtures = true` (rails_helper) — each example rolls back; no manual cleanup.

## Style
- Ruby 3.4, Rails 8.1, RuboCop (default+rails cops). One-line `it { expect { ... }.to ... }` is fine.
- Do not silence the SimpleCov per-file gate by editing `.simplecov`/`spec_helper.rb`; cover the file.
```
