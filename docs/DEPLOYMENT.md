# Deployment — production Docker image

The production deployment is a single container built from the multi-stage
`Dockerfile` (`production` target) and launched through the `production`
service in `compose.yml` (profile `prod`). It serves the Rails app over HTTP on
port 3000.

## Overview

- **Image** — `Dockerfile` target `production`: sets `RAILS_ENV=production`,
  enables static file serving, precompiles assets (`assets:precompile`), drops
  `tmp/cache`, and runs `bin/rails server -b 0.0.0.0`.
- **Runtime** — `production` compose service, profile `prod`, port `3000`.
  Secrets come from the environment; uploaded files are stored on the
  container's local disk (`config.active_storage.service = :local`).
- **Database** — a managed PostgreSQL instance (RDS/Aurora/Cloud SQL) reached
  through `DATABASE_URL`. The `db` container from the dev loop is **not** part
  of this deployment.

> **Background jobs**: the production image runs the web process only. If the
> deployment needs Sidekiq workers, launch a second container from the same
> image with the command `bundle exec sidekiq` and a shared `REDIS_URL`.

## Prerequisites

- Docker Engine with Compose V2
- A Linux VM (e.g. Ubuntu on EC2) with ports 3000 reachable
- A PostgreSQL instance with a **migration-owner** and an **application** role
- The app image secrets (see below)

## Deployment steps

### 1) Build and launch

From the repo root:

```bash
docker compose --profile prod up -d --build production
```

### 2) Environment variables

Supply these to the container (via `docker compose --profile prod up -e ...`,
an `.env` file, or the orchestration layer):

| Variable            | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `DATABASE_URL`      | `postgresql://app:...@host:5432/foodtruck_ops_production` — application role, **NOBYPASSRLS** |
| `REDIS_URL`         | Redis connection used by Sidekiq / caching                     |
| `RAILS_MASTER_KEY`  | Master key for `config/credentials/production.yml.enc`         |

`SECRET_KEY_BASE` is derived from encrypted credentials; set it explicitly only
if you do not ship `RAILS_MASTER_KEY`.

### 3) Prepare the database (migration-owner)

Migrations and seeds must run as the **migration-owner** role, and the app role
needs table grants. The dev image includes `bin/db-prepare`, which does both:

```bash
docker compose run --rm --no-deps \
  -e DATABASE_URL='postgresql://migrator:<PASSWORD>@<db-host>:5432/foodtruck_ops_production' \
  web bin/db-prepare
```

This runs `rails db:prepare` and then grants `app` `USAGE` on the schema plus
`SELECT/INSERT/UPDATE/DELETE` on all tables and `USAGE/SELECT/UPDATE` on all
sequences (including default privileges). Run it once before the first boot and
after any schema migration.

### 4) Health checks

The container exposes `/up` (`rails/health#show`), which returns `200` when the
app boots against a healthy database and `500` otherwise. Use it as the
container healthcheck and load-balancer probe:

```yaml
healthcheck:
  test: ["CMD", "curl", "-sSf", "http://localhost:3000/up"]
  interval: 15s
  timeout: 10s
  retries: 3
```

## Multi-tenant security in production

- The app connects as the non-owner `app` role (**NOBYPASSRLS**, created by
  `docker/postgres/init-app-role.sql` in dev and by the DB admin in prod).
- Tenant-scoped tables carry `FORCE ROW LEVEL SECURITY` and a
  `tenant_isolation` policy keyed on the `app.business_id` GUC (see
  TENANCY.md). Even a compromised app query cannot read another tenant's rows.
- Migrations and seeds always run as `migrator`, never as `app`; `migrator` is not a superuser and cannot bypass RLS.
- Published ports for `db` (5432) and `redis` (6379) are bound to
  `127.0.0.1` in `compose.yml`, so only processes on the host itself can
  reach them; containers talk over the internal compose network. The web
  port stays LAN-exposed so the POS can be used from a phone on the same
  network — front it with a TLS reverse proxy before exposing it beyond
  that.
- The audit trail (`audit_logs`) is tamper-evident at the database level:
  `bin/db-prepare` revokes UPDATE and DELETE from `app`, so rows can be
  appended and read but never rewritten or erased through the app role.

## Backups

The app does not manage backups. Use the database provider's point-in-time
recovery / snapshots. Static uploads live on the container's disk — attach
persistent storage or move ActiveStorage to S3 (`config/storage.yml`) before
running multiple instances.

## Scaling

The compose target is a single container on a fixed port — suitable for one VM.
For horizontal scale, run multiple instances behind a load balancer with a
shared database and a shared/object storage for uploads. `Kamal` is vendored in
the Gemfile and is the recommended path for multi-host deploys.

## Graceful shutdown

The Rails server handles `SIGTERM` and drains in-flight requests before
exiting. Stop with `docker compose --profile prod stop production`; `down`
removes the container.

## Common issues

**`/up` fails with `500`** — the app cannot reach the database or the schema
isn't migrated. Verify `DATABASE_URL` is the *application* role URL and that
`bin/db-prepare` ran as the migration-owner.

**`Permission denied for table` at runtime** — grants were never applied. Re-run
`bin/db-prepare` against the production database.

**Assets 404** — the image precompiles assets at build time; rebuild with
`--build` after changing the frontend.
