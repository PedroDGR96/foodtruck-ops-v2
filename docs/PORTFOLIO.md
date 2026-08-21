# FoodTruck Ops — Multi-Tenant Operations SaaS

## What it is

FoodTruck Ops is a multi-tenant restaurant operations SaaS: touchscreen POS,
live kitchen display (Hotwire/Turbo Streams — no page reloads), cash register
with shift and ledger tracking, one-click daily reports, menu/catalog
back-office, customers with delivery addresses, integration settings, and a
versioned JSON REST API (`/api/v1`) with bearer-token auth and Swagger
documentation (rswag).

Stack: Ruby 3.4, Rails 8.1, PostgreSQL 17 (Row-Level Security), Turbo Rails,
Sidekiq 8, Devise, Pundit, RSpec + SimpleCov.

The distinguishing engineering decision is not any single feature — it is
that **tenant isolation is enforced by PostgreSQL Row-Level Security**, with
the application structured so it is impossible to touch tenant data outside
a tenant context.

## Tenancy model

Every tenant table carries a `business_id` and an RLS policy:

```sql
CREATE POLICY tenant_isolation ON orders
  USING (business_id = current_setting('app.business_id')::uuid)
  WITH CHECK (business_id = current_setting('app.business_id')::uuid);
```

The session variable `app.business_id` is set only inside
`Tenancy.with_business(business) { ... }`, which opens a nested transaction,
issues `SET LOCAL app.business_id = <id>`, and restores/resets the setting on
exit — including unwinding through exceptions and Warden throws.

On top of RLS, the `BusinessScoped` concern gives every tenant model:

- a default scope `where(business_id: Current.business_id!)` that **raises**
  if no business is set (fail loudly, never silently leak),
- automatic assignment of `business_id` on create,
- a validation that a record can never be created for a different business.

### Entry points are all covered

| Entry point | Tenant context |
|---|---|
| Web requests | per-request `Tenancy.with_business` block |
| JSON API (`/api/v1`) | bearer token resolved first (tokens are deliberately not RLS-scoped), then the entire request runs inside `Tenancy.with_business(token.business)` |
| Sidekiq workers | client + server middleware wrapping every job in the enqueuing business |

```ruby
# app/controllers/api/v1/authentication.rb
token = Token.authenticate(bearer_token)
raise Unauthorized if token.nil? || !token.active? || token.expired?

Tenancy.with_business(token.business) do
  @current_user = token.user
  yield
end
```

One practical rule falls out of this design and is documented in the repo:
a lazy `ActiveRecord::Relation` returned from inside a tenant block must be
materialized before leaving it — reading it later re-evaluates the RLS
predicate against an unset session variable and PostgreSQL refuses the query.
Isolation failures are loud, not silent.

### Authorization

Devise handles web authentication; Pundit policies gate every resource.
Three roles (`User::ROLES = %w[owner cashier kitchen]`) separate concerns:
owners run the back office and approve daily reports, cashiers operate the
register and shifts, kitchen staff work the line — each enforced by its own
policy class, on top of the tenant isolation that applies to everyone.

## Quality gates

CI runs three stages in order and blocks on all of them:

| Stage | Tool | Bar |
|---|---|---|
| Lint | RuboCop (default + Rails cops) | zero offenses |
| Security | Brakeman | zero warnings |
| Tests | RSpec + SimpleCov | 0 failures; **95% coverage overall AND per file** |

Current state at time of writing: **629 examples, 0 failures, 99.67% line
coverage** against the per-file floor.

The per-file floor is the interesting constraint: overall coverage hides dead
code behind hot files, while a per-file minimum makes every file either
tested or deleted. It caught real problems during development — foreign code
brought in from another implementation had no specs and could not hide.

## Demo

`bin/setup && bin/dev` boots the stack with idempotent seeds (one business,
users for each role, catalog, open shift). Request/journey specs exercise the
full flow — sign in, POS order, kitchen state transitions via Turbo Streams,
payment, register movements, daily report — as part of the normal suite.

## How it is being built

Development runs through an autonomous multi-agent loop on self-hosted local
models: an orchestrator plans and reviews, worker agents implement, and every
merged change passes the full CI gate. Two rules keep it honest:

- **Evidence over claims** — work is accepted based on test/lint/security
  output, not agent self-reporting.
- **Anti-progress-illusion** — documentation may only state what the repo
  demonstrates; anything else is marked as a plan.

The next milestone uses this discipline to answer a hard question: is there a
real product here, or just a good restaurant app? A second, deliberately
different vertical (**medical center**) will be built on the same core. If
the core (tenancy, auth, audit, jobs, reporting) needs vertical-specific
hacks to support it, that failure is the signal; if it absorbs the new domain
unchanged, the extraction into a general SaaS foundation is proven.

## Keywords

multi-tenant SaaS, PostgreSQL Row-Level Security, RLS session GUC,
SET LOCAL tenancy, Pundit policies, Hotwire Turbo Streams, Sidekiq middleware,
bearer-token API, rswag/Swagger, 95% per-file coverage floor, autonomous
agent development, vertical-agnostic core
