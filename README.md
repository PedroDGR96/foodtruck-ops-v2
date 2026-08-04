# FoodTruck Ops

FoodTruck Ops is a Rails 8 operating platform for a Brazilian food truck. The
development environment is intentionally Docker-only; Ruby is not required on
the host.

## Start development

```sh
bin/setup
```

That builds the application image, starts PostgreSQL, Redis, Puma, Sidekiq, and
the Tailwind watcher, prepares the database through the migration-owner role,
and exposes the Rails health endpoint at `http://localhost:3000/up`.

Tailwind and Rails source watching use polling so bind mounts work reliably on
non-Linux host filesystems.

## Quality checks

```sh
bin/ci
```

The command runs RuboCop, Brakeman, and RSpec in Docker. SimpleCov enforces a
95% line-coverage floor (including every tracked file). GitHub Actions runs the
same checks against PostgreSQL and Redis services.

## Language, money and dates

The application is fully in Brazilian Portuguese. `I18n.default_locale` is
`:"pt-BR"` (via the `rails-i18n` gem), user-facing strings are translated in
`config/locales/*.pt-BR.yml`, money is formatted as BRL (`R$ 1.234,56`), and
dates/times are rendered as `dd/mm/aaaa hh:mm` in the business timezone. New
user-facing strings must use `I18n.t` keys in a `pt-BR` locale file — hardcoded
English in views is not allowed. Use the `format_money`, `format_date` and
`format_datetime` helpers instead of raw formatting.

## Profiles

`docker compose --profile dev up` runs the local web, worker, and Tailwind
services. `--profile test` exposes the isolated test runner, and `--profile
prod` builds the production image; production credentials must be supplied by
environment variables.

## Multi-tenant RLS

Tenant-scoped tables are protected by Postgres row-level security. The
application connects as the non-owner `app` role (NOBYPASSRLS); migrations and
seeds run as the migration-owner role. Every tenant table carries a
`business_id` UUID column, `FORCE ROW LEVEL SECURITY`, a `tenant_isolation`
policy (`USING`/`WITH CHECK` against the `app.business_id` GUC — no
`missing_ok`, so an unset tenant fails loudly), and a `BEFORE INSERT` trigger
that fills `business_id` from the GUC.

Tenant context is set through `Tenancy.with_business`, which issues `SET LOCAL`
inside a transaction (reset on completion, so no connection-pool leak). The
entry points are the request middleware, the Sidekiq client/server middleware,
the ActionCable connection/channel, and the `tenancy:console` rake task. New
tenant-scoped models use `bin/rails generate tenant_model <Name>`.

Manual verification as the `app` role (from the `db` container):

```sh
# no GUC  -> hard error (never a silent empty read)
docker compose exec db psql -U app -d foodtruck_ops_development -c \
  "SELECT COUNT(*) FROM users;"

# wrong GUC -> zero rows
docker compose exec db psql -U app -d foodtruck_ops_development -c \
  "SET app.business_id='00000000-0000-0000-0000-000000000000'; SELECT COUNT(*) FROM users;"

# right GUC -> own rows only
docker compose exec db psql -U app -d foodtruck_ops_development -c \
  "SET app.business_id='<business-uuid>'; SELECT COUNT(*) FROM users;"
```

`bin/setup` seeds a default business (`FoodTruck Ops`) and its owner user.
