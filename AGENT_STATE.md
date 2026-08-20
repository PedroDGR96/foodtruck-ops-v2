# AGENT_STATE — foodtruck-ops autonomous fleet

> Filesystem is the shared memory between agents (Pickle + local workers .172/.245).
> Update this file after any meaningful change. Companion files: `NEXT_TASK.md`,
> `WORK_LOG.md`, `KNOWN_ISSUES.md`. These four are gitignored (via `.git/info/exclude`)
> so loop gate operations never stage or dirty them, but they are present in the repo
> tree for any fresh agent to read.

## Overall project objective
Build the foodtruck-ops restaurant SaaS to a solid, demo-able state: core POS order
lifecycle, cash register, daily reports, menu/catalog, kitchen display, delivery,
JSON:API, mock integration adapters, and strict multi-tenant RLS. Keep the test gate
green (rspec 0 failures, SimpleCov ≥95 overall and per-file, rubocop, brakeman).

## Current development phase
**M1 feature-complete + autonomous audit/fix phase.** All feature branches (T6–T13)
merged to `main`. The three-model fleet (loops A/B/C) audits subsystems, finds bugs,
and lands gated patches. Loop surfaces: A = auth-users/customers-delivery/audit-log/web-surface;
B = order-lifecycle/cash-register/daily-reports; C = tenancy-rls/cart-checkout/menu-catalog/integrations.

## Completed milestones
- T6 kitchen display, T7 cash register, T8 customers, T9 daily report, T13 delivery, T10 JSON API, T11 mock adapters, T12 documentation merged to `main`.
- `bin/demo-data.rb` bootstrap seed for POS demo (catalog, gateway, open shift).
- Loop gates now enforce: rubocop → db-prepare → full rspec → `git diff --cached --stat`
  (no-op guard) → commit → ff-merge with `merged_sha == commit_sha` verification.
- Stale test-DB root cause fixed: `db_prepare` runs at startup and before every rspec gate.
- Cross-loop docker race fixed: all `docker compose` ops serialized via a shared flock.
- Completed loops (A, C) write a `COMPLETE` marker and refuse to relaunch churn.

## Current task
- Payment flows consolidated onto a single pt-BR checkout surface (`OrderPaymentController`,
  `/checkout/:id`); home dashboard is role-aware with live stats; `bin/demo-data.rb` seeds live
  orders across states (incl. a delivery order with address); kitchen display polished (T-05:
  delivery info, addons on done, rail counts); POS cart actions rescue stale lines/closed carts
  instead of 500ing (T-06); **delivery status lifecycle wired (T-08)** — order show page advances
  pending → out_for_delivery → delivered via `POST /orders/:id/out_for_delivery` and
  `POST /orders/:id/delivered` (owner/cashier policy, `RecordInvalid` rescue). Client-demo
  runbook in `docs/DEMO.md`.
- v2 lead-architect bench complete: DeepSeek (`deepseek-v4-pro-qwen3.5-9b-mtp` on `.172`) scored
  Part1 C+ / Part2 C+ / Part3 B− — same weakness class as qwopus but thinner. Verdict: qwopus
  remains the v2 lead; qwythos worker-only; DeepSeek worker/alternative. Open decision: canonical
  home for the v2 spec (v2 repo vs. spec artifact under this epic).
- Takeover loop auxiliary dispatch updated: **gemma (.245) is now the default working auxiliary**
  (reviewer/auditor/light-generator); apex (.172) reserved for lead-architect/deep-design work
  (needs `reasoning_effort:none` + `n_reasoning_tokens:0` workaround).

## Current owner
- Big Pickle (takeover session) on `main`. Local loops A/B/C parked (COMPLETE markers written).
- Bench transport agents pinned to `.172` models: `067a6d93` (exited; `qwopus3.5-4b-coder` gone
  from `.172`), `1f68a594` (qwythos). DeepSeek tested directly via raw chat-completions API.

## Blocked tasks / known failures
- See `KNOWN_ISSUES.md`. Nothing blocks the fleet (machine down ⇒ loop waits/falls back).

## Next recommended tasks
1. Add a delivery order (with address) to `bin/demo-data.rb` to showcase the delivery rail.
2. Polish the kitchen display for the demo (KDS handoff already wired via broadcasts).
3. Run full `bin/ci` on main after each change.

## Important architectural decisions
- Multi-tenant isolation = Postgres RLS via `app.business_id` GUC, never AR scopes alone.
  All tenant queries MUST run inside `Tenancy.with_business(...)`. Lazy relations read
  outside the block hit `PG::InvalidTextRepresentation uuid: ""`.
- Loops commit to per-loop branches (A→`main`, B→`loop/parallel-b`, C→`loop/parallel-c`);
  each uses its own `TEST_DB` (t13/t14/t15) and its own git patch-branch prefix.
- Patches restricted to `app/ spec/ lib/ bin/demo-data.rb config/routes.rb`.
- Executor = qwopus3.5-4b-coder@bf16 on `.172`; planners = gemma-4-e2b (`.245` A/B, `.85` C).

## Test status
- `main` @ `8a5df14` — rspec **540/0**, SimpleCov **99.7%+** (overall + per-file ≥95),
  rubocop clean, brakeman clean. `orders_controller.rb` per-file back to **100%** after
  stub-based rescue specs (was 94.73%).

## Last meaningful change
- 2026-08-15 — Big Pickle (takeover): T-08 delivery status lifecycle wired end-to-end
  (routes/controller/policy/locale/view + 6 request specs); gate green (540/0, 99.7%+).
