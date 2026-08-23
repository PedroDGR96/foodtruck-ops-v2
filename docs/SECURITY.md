# Security Policy

Enforced controls and stances for this repository. Last reviewed: 2026-08-23.

## Gate (bin/ci)

Every merge to main passes: `rubocop`, `brakeman --no-pager`,
`bundler-audit check --update`, `rspec` with SimpleCov >= 95% overall and
per-file. A gate failure blocks the merge; there are no override flags.

## Dependency advisories

`bundler-audit` runs against a freshly updated ruby-advisory-db on every
gate run and fails on any known advisory affecting the locked gems.

Response procedure when it fires:
1. Assess exploitability against our actual usage (modules enabled, config).
2. Bump the gem (`bundle update <gem>`), rebuild the test image
   (`docker compose --profile test build test`) — Gemfile changes are NOT
   visible to cached images.
3. Full `bin/ci`, then ship.

Recent example: devise 4.9.4 -> 5.0.4 for CVE-2026-32700 / CVE-2026-40295.

## Upload processing (Active Storage + libvips)

Product/staff uploads flow through Active Storage variants processed by
libvips (Rails 8 default). Controls:
- Keep `activestorage` at or above the latest patched release
  (CVE-2026-66066 "KindaRails2Shell" class: variant params reaching unfuzzed
  libvips ops -> file read -> RCE).
- `VIPS_BLOCK_UNTRUSTED=1` is set for every compose service (dev, worker,
  test) as defense-in-depth: untrusted libvips operations are blocked even
  if attacker-controlled parameters ever reach the processor again.

## Redirects

Only `redirect_back fallback_location: <internal path>` is allowed. Raw
`request.referrer`/`request.referer` values must never feed `redirect_to`
(open-redirect class of CVE-2026-40295). Brakeman plus review enforce this.

## Tenancy & database

Tenant isolation is enforced by PostgreSQL RLS keyed on `app.business_id`
(see AGENTS.md). Database traffic requires TLS (`sslmode=require`; server
cert generated per container). Postgres and Redis publish on loopback only.

## Known backlog

- Digest-pin base images and add a container scanner step.
- SBOM emission per release.
