# Contributing — Code Style, Tests & Commit Policy

Everything in this guide is enforced by `bin/ci` (RuboCop, Brakeman, RSpec with
a SimpleCov ≥95% line-coverage floor) and by the shared conventions documented
here and in DEVELOPMENT.md.

## Code style

- **Ruby/Rails:** Ruby 3.4 (`ruby-3.4.10`), Rails 8.1. Small focused methods;
  descriptive names; minimal comments that capture intent.
- **Linting:** `bin/rubocop` must pass with zero offenses; `bin/brakeman` with
  no new high/critical findings; `bin/bundler-audit` clean.
- **Language:** all user-facing strings in Brazilian Portuguese through
  `I18n.t` keys in `config/locales/*.pt-BR.yml`. Default locale `pt-BR`;
  `en.yml` is not a source of duplicate user-facing strings.
- **Money/time:** `decimal(12,2)` BRL, never float; totals recomputed from line
  items; dates rendered `dd/mm/aaaa hh:mm` in the business timezone. Use the
  `format_money`/`format_date`/`format_datetime` helpers.
- **Naming:** snake_case for files/methods/columns, CamelCase for classes.

## Database & schema

- **Multi-tenancy:** every tenant-scoped table carries a `business_id uuid NOT
  NULL`, `FORCE ROW LEVEL SECURITY`, a `tenant_isolation` policy and a
  `BEFORE INSERT` trigger that fills `business_id` from the `app.business_id`
  GUC. Never create tenant tables without this. Generate them with
  `bin/rails generate tenant_model <Name>`.
- **Roles:** `app` (runtime, NOBYPASSRLS) and `app_owner` (migrations/seeds).
  Migrations and seeds never run as `app`.
- **Schema format:** `:sql` — after any migration, `db/structure.sql` is
  regenerated (`bin/rails db:schema:dump`) and committed.
- **Migrations:** additive, idempotent where sensible, with a `down` method.

## Tests & coverage

- **Framework:** RSpec + FactoryBot + Capybara + SimpleCov.
- **Floor:** ≥95% line coverage across tracked files, enforced in CI.
- **Required:** every new code path ships unit/request/system specs; new UI
  flows ship system specs (`spec/system/`).
- **No TODOs/FIXMEs** in production code — track known issues elsewhere.

## Tenancy conventions

- Tenant models include `BusinessScoped`; children validate parents with
  `validates_parent_business_for`.
- Background jobs that need a tenant use `BusinessJob.perform_later_for(business, ...)`.
- Manual/console work uses `bin/rails "tenancy:console[<business-id>]"`.

## APIs

- A JSON API (JSON:API wire format, versioned under `/api/v1/`, documented with
  rswag/Swagger) is **planned** (T10, branch `t11-json-api`) but not merged.
  Until it lands, the app is server-rendered Hotwire. Don't add REST endpoints
  for the UI; extend the planned API ticket instead.

## Frontend

- Hotwire (Turbo) + Stimulus + Tailwind, assets via Propshaft. All UI text in
  pt-BR via `I18n.t`. No English copy, no hardcoded currency formats.

## Containerization

- Dev stack: `docker compose up -d --build db redis`, then
  `docker compose --profile dev up -d web worker tailwind` — or just
  `bin/setup` (see SETUP.md).
- Quality gate: `bin/ci` (runs RuboCop, Brakeman, RSpec in Docker against the
  `test` compose profile).
- Production: `docker compose --profile prod up -d --build production` (see
  DEPLOYMENT.md).
- CI mirrors this in `.github/workflows/ci.yml` (GitHub Actions with
  PostgreSQL + Redis services and the `app` role bootstrap).

## Git workflow

- **Branches:** `{ticket}-{short-summary}` (e.g. `t12-documentation`,
  `t8-customers`). No `feature/...` prefixes.
- **Commits:** small, focused; imperative present tense; ≤72 chars; no trailing
  period. Examples: `feat: add kitchen display UI`, `fix: handle nil customer
  in order calculation`, `docs: update setup guide`.
- **One commit per ticket on a branch**, then open a PR against `main`.
- **Merging:** rebase onto `main` first; squash-merge on approval. At least one
  non-author reviewer. `bin/ci` must be green.
- **PR description:** summary of changes, verification steps, and files touched.

## Contribution workflow

1. `git checkout -b t12-documentation <base>`
2. Implement on the branch. Run `bin/rubocop` and the focused specs as you go.
3. Run `bin/ci` and keep coverage ≥95%.
4. Update docs (`docs/`) for any new patterns/features.
5. Commit (`feat:`/`fix:`/`docs:` + scope).
6. Push and open a PR; request review.
7. After approval, squash-merge to `main`.

## Common pitfalls

- **Tenant context missing in a job** → use `BusinessJob.perform_later_for` or
  wrap the work in `Tenancy.with_business`.
- **English leak in the UI** → add an `I18n.t` key under a `pt-BR` locale file;
  never hardcode strings.
- **Money rounding drift** → recompute totals from line items and add-ons
  (`Order#recalculate_totals!`); keep `total == subtotal + tax`.
- **Cross-tenant association** → add/keep `validates_parent_business_for` on
  the child model; verify with the psql checks in DEVELOPMENT.md.
- **CI red on schema** → commit the regenerated `db/structure.sql` alongside
  the migration.
