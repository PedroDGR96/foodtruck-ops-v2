# Setup — Docker dev loop

This guide gets a fresh machine running the full stack in development. Ruby is
**not** required on the host — everything runs inside Docker. It covers the
prerequisites, the single `bin/setup` command, what each step does, and the
manual equivalents.

## Prerequisites

- Git and Bash (on Windows, use Git Bash or WSL2)
- Docker Engine with Compose V2 (`docker compose version` works)
- Ports **3000** (Rails), **5432** (Postgres) and **6379** (Redis) free on the host
- ~6 GB free disk and ≥4 GB RAM

## Quick start

From the repo root, run:

```bash
bin/setup
```

`bin/setup` performs, in order:

1. `docker compose up -d --build db redis` — starts the Postgres and Redis
   containers (the `db` image also runs `docker/postgres/init-app-role.sql`,
   which creates the non-owner `app` role on first boot).
2. `docker compose run --rm --no-deps -e DATABASE_URL=postgresql://app_owner:app_owner@db:5432/foodtruck_ops_development web bin/db-prepare`
   — as the **migration-owner** (`app_owner`) role: migrates the schema
   (`rails db:prepare`) and grants schema/table privileges to the `app` role.
3. `docker compose --profile dev up -d web worker tailwind` — starts the
   Rails server (port 3000), Sidekiq, and the Tailwind watcher.
4. A boot check (`rails runner`) and the success message
   `FoodTruck Ops is running at http://localhost:3000/up`.

The command is idempotent — re-run it any time to bring the stack back up.

## Verify it's up

Open a new terminal and hit the health endpoint:

```bash
curl -s http://localhost:3000/up
```

A `200` with body `Rails: OK` means the app booted and the database connected.
`/up` is Rails' built-in health check (`get "up" => "rails/health#show"` in
`config/routes.rb`); it returns `500` if the app fails to boot.

Then sign in at <http://localhost:3000/users/sign_in> with the seeded
credentials (see next section).

## What gets seeded

`bin/db-prepare` also runs `db/seeds.rb`, which creates (idempotently):

- the default business `FoodTruck Ops` (currency `BRL`, timezone
  `America/Sao_Paulo`)
- three users, all with password `password123` by default (override with the
  `OWNER_PASSWORD` env var):

| Email                    | Role      |
|--------------------------|-----------|
| `owner@foodtruck.local`  | `owner`   |
| `cashier@foodtruck.local`| `cashier` |
| `kitchen@foodtruck.local`| `kitchen` |

Menu items are **not** seeded — create categories/products from the back-office
(`/categories`, `/products`) after signing in as the owner.

## Manual setup (same steps, no `bin/setup`)

```bash
# 1. Start database + redis
docker compose up -d db redis

# 2. Prepare schema as migration-owner and grant app privileges
docker compose run --rm --no-deps \
  -e DATABASE_URL=postgresql://app_owner:app_owner@db:5432/foodtruck_ops_development \
  web bin/db-prepare

# 3. Start web + worker + tailwind
docker compose --profile dev up -d web worker tailwind
```

## What each compose service does

`docker compose up` starts `db` and `redis` unconditionally. The app services
are gated behind profiles (see `compose.yml`):

| Service    | Profile | Command                                  | Port |
|------------|---------|------------------------------------------|------|
| `db`       | —       | `postgres:17` (runs `init-app-role.sql`) | 5432 |
| `redis`    | —       | `redis:7-alpine`                         | 6379 |
| `web`      | `dev`   | `bin/rails server -b 0.0.0.0`            | 3000 |
| `worker`   | `dev`   | `bundle exec sidekiq`                    | —    |
| `tailwind` | `dev`   | `bin/rails tailwindcss:watch`            | —    |
| `test`     | `test`  | `bundle exec rspec` (used by `bin/ci`)   | —    |
| `production`| `prod`  | production image (see DEPLOYMENT.md)     | 3000 |

The dev image mounts the repo at `/rails` with polling file watching, so
edits on any host filesystem hot-reload.

## Common issues

**`curl /up` returns 500 / connection refused** — the Rails container is still
booting or a dependency isn't healthy. Check `docker compose ps` (both `db` and
`redis` must be `healthy`) and `docker compose logs -f web`.

**Port already in use** — stop whatever occupies 3000/5432/6379, or remap the
offending service in `compose.yml` (e.g. `"3001:3000"`).

**First boot is slow** — the dev image builds the Gem bundle; subsequent runs
reuse the cached image.
