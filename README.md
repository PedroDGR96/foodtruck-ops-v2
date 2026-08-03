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

## Profiles

`docker compose --profile dev up` runs the local web, worker, and Tailwind
services. `--profile test` exposes the isolated test runner, and `--profile
prod` builds the production image; production credentials must be supplied by
environment variables.
