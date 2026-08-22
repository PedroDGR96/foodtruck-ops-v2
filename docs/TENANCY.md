# Tenancy — RLS, `Tenancy.with_business` and `Current`

Tenant isolation is enforced at **two layers**: the application always scopes
queries through the `BusinessScoped` concern, and PostgreSQL backs it up with
Row-Level Security (RLS) so a query cannot escape its tenant even if the
application layer is bypassed.

## The actors

| Piece | Location | Role |
|-------|----------|------|
| `Current` | `app/models/current.rb` | thread-local `business` accessor (`ActiveSupport::CurrentAttributes`) |
| `BusinessScoped` | `app/models/concerns/business_scoped.rb` | model concern: belongs_to `business`, default scope, assignment on create |
| `Tenancy.with_business` | `lib/tenancy.rb` | sets the GUC + `Current` for a block, inside a transaction |
| `TenantMiddleware` | `app/middleware/tenant_middleware.rb` | sets tenant context per HTTP request |
| Sidekiq middleware | `lib/tenancy/sidekiq_*.rb` | sets tenant context per job |
| DB roles | `app` (NOBYPASSRLS) / `migrator` (no superuser, no BYPASSRLS) | runtime vs migration/seed role |
| RLS policies | `db/structure.sql` | `tenant_isolation` policy + `assign_business_id_from_guc()` trigger |

## Application layer

### `Current`

`Current` is a `CurrentAttributes` object holding the active business:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :business

  def business_id
    business&.id
  end

  def business_id!
    business_id || raise(Tenancy::TenantNotSetError, "No current business has been set")
  end
end
```

### `BusinessScoped`

Every model that belongs to exactly one business includes `BusinessScoped`:

```ruby
module BusinessScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :business
    default_scope { where(business_id: Current.business_id!) }
    before_validation :assign_current_business, on: :create
    validate :business_matches_current_business, on: :create
  end
  # ...assigns business_id from Current on create, and fails validation
  # if the assigned business_id does not match the current tenant.
end
```

Child rows that reference a parent are further protected by `TenantChild`,
which validates (`validates_parent_business_for`) that every parent association
belongs to the same business.

### `Tenancy.with_business`

The single entry point for setting tenant context. It sets `Current.business`,
opens a transaction, and issues `SET LOCAL app.business_id = '<uuid>'`, so the
GUC is scoped to the transaction and cannot leak through the connection pool:

```ruby
Tenancy.with_business(business) do
  # GUC app.business_id is set; queries are scoped
end
```

It accepts a `Business` or a business UUID, raises `TenantNotSetError` on a
blank value, and always restores/resets the GUC when the block finishes.

## HTTP request flow

1. `TenantMiddleware` is inserted **after** `Warden::Manager`
   (`config/application.rb`). For every request it resolves the business as
   `Current.business || warden user's business`, wraps the app call in
   `Tenancy.with_business(business)`, and resets `Current` on the way out.
2. **Sign-in** (`Users::SessionsController#create`) looks the user up by email
   (`User.unscoped`), opens `Tenancy.with_business(user.business)`, and only
   then authenticates — so the session audit log is written inside the right
   tenant.
3. **ActionCable** — `ApplicationCable::Connection#connect` identifies the
   connection by `current_user` and `business`; channels (e.g. `OrderChannel`)
   stream from `"orders_<business_id>"`.

## Background jobs

Sidekiq is wired with client and server middleware
(`config/initializers/sidekiq.rb`) that restore the caller's tenant context on
the worker. Jobs that need a specific business use `BusinessJob.perform_later_for`:

```ruby
BusinessJob.perform_later_for(business, *arguments)
```

## Database layer (RLS)

`db/structure.sql` defines, for each tenant-scoped table **except `users`**:

- `business_id uuid NOT NULL` + index on `business_id`
- `ALTER TABLE ... FORCE ROW LEVEL SECURITY`
- a `tenant_isolation` policy:

```sql
CREATE POLICY tenant_isolation ON public.<table>
  USING ((business_id = (current_setting('app.business_id'))::uuid))
  WITH CHECK ((business_id = (current_setting('app.business_id'))::uuid));
```

- a `BEFORE INSERT` trigger calling `assign_business_id_from_guc()`, which
  fills `business_id` from the GUC so an unset tenant fails loudly instead of
  silently mis-scoping:

```sql
CREATE TRIGGER <table>_set_business_id
  BEFORE INSERT ON public.<table>
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_business_id_from_guc();
```

**`users` is the deliberate exception**: it is scoped at the application layer
(`BusinessScoped`) but has no RLS policy or trigger, because authentication must
find a user across tenants via `User.unscoped`. `businesses` is the tenant root
and has no `business_id` column or RLS. All other tenant tables are under RLS.

### Roles

- **`app`** — the runtime role used by `DATABASE_URL`. Created
  `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS` (dev:
  `docker/postgres/init-app-role.sql`; CI: `.github/workflows/ci.yml`). Because
  it is `NOBYPASSRLS`, RLS policies apply to it.
- **`migrator`** — owns migrations and seeds. Created
  `LOGIN NOSUPERUSER NOBYPASSRLS CREATEDB CREATEROLE`; owns the application
  databases and every object in them. Grants to `app` are applied by
  `bin/db-prepare` (`GRANT USAGE ... ON SCHEMA public`, table/sequence
  privileges, and default privileges).
- **`app_owner`** — idle bootstrap superuser created by the postgres image.
  PostgreSQL 17 refuses to demote it, so it is left owning nothing
  user-visible; routine operations never use it (CIS PostgreSQL Benchmark:
  no superuser for routine operations).
- **`dbadmin`** — break-glass superuser for genuine emergencies.

## Verification

As the `app` role from the `db` container:

```sh
# no GUC -> hard error (RLS "does not exist" / no permission), never a silent empty read
docker compose exec db psql -U app -d foodtruck_ops_development -c \
  "SELECT COUNT(*) FROM orders;"

# wrong GUC -> zero rows
docker compose exec db psql -U app -d foodtruck_ops_development -c \
  "SET app.business_id='00000000-0000-0000-0000-000000000000'; SELECT COUNT(*) FROM orders;"

# right GUC -> own rows only
docker compose exec db psql -U app -d foodtruck_ops_development -c \
  "SET app.business_id='<business-uuid>'; SELECT COUNT(*) FROM orders;"
```

## Rake task

Open a console bound to a business (useful for tenant-scoped maintenance):

```bash
bin/rails "tenancy:console[<business-uuid>]"
```

New tenant-scoped models should be generated with the project generator:

```bash
bin/rails generate tenant_model <Name>
```
