# AGENT_STATE — foodtruck-ops (single-loop era)

> Filesystem is the shared memory between agents and the autonomous loop. Update
> this file after any meaningful operator-side change. Frozen paths for the loop:
> `app/core/ spec/core/ spec/rls/ spec/i18n/ docker/postgres/ bin/ db/ config/`
> (except `config/routes.rb`) + `Gemfile*` + `.gitignore`. `loop-findings.md`
> is gitignored via `.git/info/exclude` (loop's live findings store).

## Overall project objective
Build the foodtruck-ops restaurant SaaS to a demo-able, client-pitch state: core POS
order lifecycle, cash register, daily reports, kitchen display, delivery, JSON:API,
mock integration adapters, strict multi-tenant RLS. Gate must stay green: rspec 0
failures, SimpleCov ≥95 overall AND per-file, rubocop, brakeman (`bin/ci`). The
**Integrações tab** is the current client-facing milestone (see `docs/DEMO.md`).

## Current development phase
**Single autonomous loop on `main`** (replaces the aug-20 loops A/B/C, all retired).
- Loop: `hermes-router.service` on `.172` (systemd, `Restart=always`), steerable via
  `PRIORITIES.md` (bullet-style, no `## DIRECTIVE` headers — `directives_active`
  handles that). Rootless restart path: `kill <MainPID>` → systemd revives ≤10s.
- Loop engine notes (2026-09-06): `directives_active` fixed for empty directive
  blocks (backup `loop.py.bak-20260906-225838`). Executor feed capped at
  `EXECUTOR_FEED_CHARS=17600` (~4.4k tokens).
- Fleet topology (2026-09-06, `.85` back online):
  - **.85 / rtx5050** = PLANNER `qwen3.8-distilled-4b-npu2` (~310 tok/s) — pinned via
    `PLANNER_MODEL`/`PLANNER_BACKEND=rtx5050` in `start.sh`.
  - **.172 / mi50** = EXECUTOR elastic on the single loaded Q6_K
    (`qwen3.6-14b-a3b-fablevibes`, **262144 ctx / Q8_0 K+V / 12 experts** — benched
    2026-09-06: apply-PASS at 55–60 tok/s, Q8 near-lossless, 262k beyond native 131k
    but loop feeds are tiny → no practical regress).
  - **.245 / rx6600** = REVIEWER `qwen3.8-2b-sft-fable5` (`REVIEWER_BACKEND=rx6600`).

## Completed milestones
- T6–T13 feature work merged to `main` (kitchen display, cash register, customers,
  daily report, delivery, JSON:API, mock adapters) + doc cleanup (aug 2026).
- Multi-tenant RLS (Postgres GUC `app.business_id`, `Tenancy.with_business`,
  `BusinessScoped` default scope) — never run tenant queries outside the block.
- **Integrações demo milestone (2026-09-06)**: owner nav+footer "Integrações" link,
  `IntegrationsController#test_connection` running each real mock adapter
  (`MockPaymentGateway`, `MockMapsProvider`/OSM, `MockFiscalProvider`,
  `MockMarketplaceProvider`, `MockMessagingProvider`) returning
  `{success:, message:}`; `OrderPaymentController#create` authorized via
  `MockPaymentGateway` (deterministic, offline, idempotent by order).
  Live-verified end-to-end at `:3000` (owner@foodtruck.local / password123).
  Two demo bugs fixed + gated: `test_maps_connection` routed through
  `MockMapsProvider` (was a dead `MockGoogleMapsProvider` NameError) and
  required api_key; added `integrations.providers.unknown/error` i18n keys.

## Current loop steering (PRIORITIES.md)
- **night-01 (PATCH)**: mask truncated credential echoes in mock adapter success
  messages — `MockPaymentGateway` `(chave: …)` done (loop iters 5659/5668);
  `MockMessagingProvider` `(SID: …)` **still open**; extend
  `spec/requests/integrations_spec.rb` to assert no credential fragments.
- **night-02 (AUDIT, standing)**: demo-flow regression watch on `docs/DEMO.md`
  (POS → checkout → payment → kitchen → report → cash register + Integrações tab).
- Patch domain: `app/ spec/ lib/ config/routes.rb` only (not the frozen list above).

## Current owner / watchers
- Operator: pedro-goes8083. Loop engine runs under systemd on `.172` (user-time;
  the `foodtruck-autopush.timer` is a USER unit, active every 30 min, log at
  `~/.local/state/foodtruck-autopush.log`; a failed `--tags` push is a non-fatal
  tag race — manual `git push origin main` clears it).
- Night watch: `night-monitor` agent (a2906ad6) on **opencode:mimo-v2.5-free**
  (backup: `.245`); watchdog script `~/.local/bin/night-monitor-watchdog.sh`
  (persistent shell) auto-flips the monitor to `.245` if 3 pings go unanswered.

## Blocked / known issues
- See `KNOWN_ISSUES.md` (dated; P1 tenancy items verified addressed historically).
- `systemctl stop` on the loop service times out (D-Bus) — use rootless `kill`.
- Loop reverts `PRIORITIES.md`? No — editing it is the steering channel; deleting
  retires the loop.

## Important architectural decisions
- Multi-tenant isolation = Postgres RLS via `app.business_id` GUC, never AR scopes
  alone. Lazy relations read outside `Tenancy.with_business` → `uuid: ""` error.
- Demo is offline-first: only deterministic mock adapters, never real providers.
- Loop commits gated on rspec 0 failures + SimpleCov ≥95 overall+per-file; never
  weaken a spec; UI strings only via `config/locales/pt-BR.yml` (operator-side).
- `app/core` is Tier-1 frozen for the loop (core convergence is operator/mannual).

## Test status
- `main` @ `46d790a` (pushed): rspec **795/0**, SimpleCov **99.40%** (2026-09-06),
  rubocop + brakeman clean. Canonical repo: `~/Desktop/foodtruck-ops-v2`.

## Last meaningful change
- 2026-09-06 — Integrações demo milestone complete + pushed (`607d52d`, `46d790a`);
  loop un-wedged and productive (iter ~5695), `directives_active` crash fixed,
  fleet topology restored (planner → .85, executor → .172 262k/Q8). Diary:
  `~/Desktop/diary/entries/2026-09-06.md` (entry 04).