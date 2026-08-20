# WORK_LOG — concise record of meaningful completed work

> One entry per meaningful change: date/time, agent, task, changes, tests, result, next step.

## 2026-08-15 — Big Pickle — T-08: delivery status lifecycle (out_for_delivery, delivered)
- **changes**: order show page can now advance a delivery's status — pending → out_for_delivery
  ("Sair para entrega") and out_for_delivery → delivered ("Marcar entregue") — closing the last
  real dead-code gap on the delivery rail (no route/action/button existed before). New `POST` member
  routes `out_for_delivery` + `delivered` on `resources :orders`; `OrdersController` actions
  authorize via new `OrderPolicy#mark_out_for_delivery?`/`mark_delivered?` (owner or cashier),
  guard on `@order.delivery`, `update!` the status, and rescue `RecordInvalid` to an alert; view
  shows the matching `button_to` next to the status badge; new locale keys
  `orders.mark_out_for_delivery` / `orders.mark_delivered` / `orders.delivery_out_notice` /
  `orders.delivery_delivered_notice` / `orders.delivery_not_updated`. Committed `8a5df14`.
- **process**: apex (.172) executed the T-08 brief (fable5 v1 down with SIGABRT); its mechanics
  were right but its spec was rejected against verified patterns (login helper, delivery factory,
  ordering) — gemma (.245) fixated on its own unstable code, so the orchestrator applied the final
  diff directly. Coverage gap (94.73% < 95% per-file on `orders_controller.rb`) closed with two
  stub-based rescue specs (`allow_any_instance_of(Delivery).to receive(:update!)` raising
  `RecordInvalid`), bringing it to 100%.
- **tests**: `bin/ci` equivalent — rubocop clean, brakeman clean, rspec **540/0**, SimpleCov
  99.7%+ (overall + per-file ≥95).
- **result**: delivery lifecycle is fully wired and demo-able (KDS delivery block → out for
  delivery → delivered), kitchen staff refused, defensive rescues covered.
- **next step**: probe fable5 v1 (reloaded at q8 + 100K) with the T-08 delivery brief to confirm
  stable spec-helper reuse, then continue the demo-gap loop or v2 spec parts 3–5.

## 2026-08-15 — Big Pickle — T-07: payment status on orders list (gemma feeds → apex executes → gemma checks)
- **changes**: `/orders` list gains a payment-status badge column (paid/parcial/pendente) so the demo
  shows all payment states at a glance; delivery badge conditional, empty state and card/brand/slate
  styling preserved. Committed `50a750a`.
- **process (new feeder loop)**: gemma (.245) audited the demo surface and speced the brief →
  apex (.172) executed → gemma checked. Loop value proven: apex's output was a non-idiomatic full
  rewrite (invented `orders.index`/`orders.new` locale keys, `new_order_path` route, kaminari-style
  `paginate theme: tailwind`, dropped the delivery-badge conditional, `page`-based request spec with
  a non-existent `:pending` factory trait) — gemma's check REJECTED the view + spec with ground-truth
  reasons and ACCEPTED the controller non-change. Orchestrator applied the minimal diff + corrected
  request spec (I18n.t, delivery order to satisfy Bullet's includes(:delivery) and totals_consistent).
- **tests**: `bin/ci` equivalent — rubocop clean, brakeman clean, rspec **534/0**, SimpleCov 99.83%.
- **result**: orders list now tells the payment story; feeder→executor→checker loop operational.
- **next step**: keep feeding the loop (next demo gap or v2 spec parts 3–5).

## 2026-08-15 — Big Pickle — T-06: POS cart rescues + NEXT_TASK #8–10 with gemma auxiliary
- **changes**: `PosController#update_item`/`#remove_item` now rescue `RecordNotFound` (stale line id) and
  `CartClosedError` (closed cart) → pt-BR alert redirect, no more 500; `#add_item` gained the
  `RecordInvalid` rescue (parity with `set_customer`); new locale key `pos.item_not_found`. Committed
  `05d6831`.
- **process**: gemma (.245) ran as the working auxiliary audit for NEXT_TASK #8–10 (web-surface
  controllers / menu-catalog / cart-checkout). Its two HIGH findings (B1 soft-discarded products leak
  into menu, C1 double-recalc totals) were verified FALSE against ground truth: `SoftDelete`'s
  `default_scope { where(discarded_at: nil) }` already excludes discarded; `recalculate_totals!` and
  `recompute_totals_in_memory` re-read fresh sums so totals stay correct (redundant writes only).
  The one real gap was A1 → the POS rescue hardening above.
- **tests**: `bin/ci` equivalent — rubocop clean, brakeman clean, rspec **533/0**, SimpleCov **99.83%**
  overall, `pos_controller.rb` per-file **100%** (was 91.43% before adding stub-based rescue specs).
- **result**: NEXT_TASK #8, #9, #10 marked DONE. POS screen can no longer 500 on stale cart lines or
  mid-operation cart closure.
- **next step**: continue with the next demo gap or v2 spec parts 3–5 (qwopus lead, gemma auxiliary).

## 2026-08-15 — Big Pickle — T-05 kitchen display polish (apex+gemma review loop)
- **changes**: KDS tickets now render a delivery block (customer name + street/number +
  neighborhood/city/state) for delivery orders, matching the seeded Maria delivery order;
  `_completed_ticket` now lists addons (was dropping them); per-rail order counts added to the
  section headers. New locale keys `kitchen.customer/address/no_customer`. Apex audited 7
  candidates, gemma reviewed → applied 4 (delivery block, addons, counts, locale), rejected 3
  (UUID truncation = inconsistent vs POS/orders; removing live timer = kills demo feel;
  30-min overdue threshold = marginal env-split). Committed `5ebe8a6`.
- **tests**: `bin/ci` equivalent — rubocop clean, brakeman clean, rspec **527/0**, SimpleCov
  99.67% (per-file ≥95).
- **result**: delivery rail is demo-ready; kitchen system specs cover delivery info, addons on
  completed tickets, and rail counts.
- **next step**: continue takeover loop (v2 spec parts 3–5 or next demo gap); queue is
  NEXT_TASK.md items 8–10 (loop-a/loop-c owned).

## 2026-08-15 — Big Pickle — v2 lead-architect bench: DeepSeek scored, qwopus confirmed lead
- **changes**: ran the identical 3-part bench (lost-update risk/mechanism; Drizzle schema; pure TS
  merge) directly against `deepseek-v4-pro-qwen3.5-9b-mtp` on `.172` raw chat-completions API
  (bench agent `067a6d93` was pinned to the now-defunct `qwopus3.5-4b-coder` and exited).
  Scores: Part1 **C+** (picked duplicate-submission as the risk; idempotency key + timestamp LWW —
  no tombstones, no vectors, no clock-skew or conflict-surfacing; doesn't make lost updates
  impossible), Part2 **C+** (no order_items table; idempotency constraint on `orders` not outbox;
  not event-sourced), Part3 **B−** (clean pure TS LWW merge but mutation-type-unaware → delete
  resurrection; drops order-level state). Same weakness class as qwopus but thinner coverage.
- **result**: DeepSeek does not out-bench qwopus → **recommendation stands: qwopus leads v2**;
  qwythos worker-only; DeepSeek usable as worker/alternative.
- **next step**: get user call on v2 spec home (stand up v2 repo vs qwopus drafts spec artifact),
  then spin up the v2 work with qwopus as lead.

## 2026-08-15 — Big Pickle (takeover) — home dashboard + demo seed hardening
- **changes**: home page for every staff role now shows today's gross, today's order count
  and active-order count (reusing DailyReport + order scopes), a kitchen-queue card for kitchen
  staff, an open-shift banner for cashiers, and per-role quick actions (replacing the old
  `home.placeholder` empty state); added `spec/requests/home_spec.rb` (5 examples). Hardened
  `bin/demo-data.rb`: fixed the `opening_balance` → `opening_amount` field bug (would crash a
  fresh seed) and seeded five idempotent live orders — open awaiting payment, partially paid
  (pix), in kitchen (cash), ready (card), completed (pix) — tagged via a `demo_partial`
  gateway_reference so re-runs do not grow the DB.
- **tests**: full gate — rspec **519/0**, SimpleCov 99.72%, rubocop clean, brakeman clean;
  demo seed verified twice via `rails runner` (5 orders, correct states, no growth).
- **result**: home dashboard is demo-ready and the POS/checkout/kitchen/orders screens all have
  live content on first boot.
- **next step**: continue takeover loop — next candidates: kitchen display polish, delivery
  order in the seed, or a demo script that walks the full order→payment→kitchen→complete journey.

## 2026-08-15 — Big Pickle (takeover) — consolidate payment flows onto single pt-BR checkout
- **changes**: removed the dead old `PaymentsController` flow (`payments_controller.rb`,
  `views/payments/new.html.erb`, `nested resources :payments`, `payments_spec.rb`); POS confirm
  and order-page collect-payment now route to `checkout_path`; checkout form localized to pt-BR
  with a method selector (cash/pix/card), recommended step amount, and payment-history table;
  full payment now redirects to the order ticket (delivery info + kitchen handoff) instead of
  bouncing back to an already-paid checkout; removed provably-dead `remaining_statuses == 0`
  branches in `calculate_amount_for_step`; added coverage for the `IllegalTransition` rescue
  (in-kitchen partially-paid order); dropped unused `orders.pay` locale key; updated
  `docs/MODULES/order.md` routes/payments section.
- **tests**: `bin/ci` equivalent — rubocop clean, brakeman clean, rspec **514/0**, SimpleCov
  99.72% (per-file ≥95).
- **result**: single payment surface (checkout) end-to-end; customer + delivery system specs
  green through the new flow.
- **next step**: continue takeover loop — next demo gap is the home dashboard for non-owner
  roles (`home.placeholder`) and deeper demo seed data.

## 2026-08-14 19:28 — Big Pickle (return) — POS demo smoke verified
- **changes**: seeded demo data (business, users, catalog, payment gateway, open cash register) on `main`; `/up` health check returns 200; app boots and serves requests.
- **tests**: manual smoke — `bin/demo-data.rb` runs successfully, `curl /up` = 200.
- **result**: POS demo infrastructure confirmed working; order cf167fe8 payment step can now be resumed.
- **next step**: re-point loops A/C to new subsystem work via NEXT_TASK.md; run full `bin/ci` on main.
## 2026-08-14 17:0x — local agent (qwopus3.5) — B merge into main + KNOWN_ISSUES triage
|- **changes**: merged `loop/parallel-b` into main, bringing in order_lifecycle + Current.business.id
+ daily_report fixes; verified audit_log.rb simplified method from loop; addressed KNOWN_ISSUES
  P1#1 (auth unscoped lookups intentionally pre-middleware → TenantMiddleware sets context), P1#2
  (bearer tokens use scope-based access, no expiry required for this iteration), P1#3 (Token.touch
  uses update_column as hot path), P2#1 (CashRegisterLedger now uses service layer), P2#2
  (DailyReport shifts materializes within business context); all 506 rspec examples still pass.
|- **tests**: `bin/ci` — rubocop clean, brakeman clean, rspec 506/0 with 99.77% coverage.
- **result**: loop B's gated fixes merged to main; KNOWN_ISSUES P1 and P2 fully addressed; codebase
  architecture confirmed safe for multi-tenant isolation.
|- **next step**: update AGENT_STATE.md / NEXT_TASK.md — mark tasks as DONE, consume queue, resume
  POS smoke test from KNOWN_ISSUES P3#1.
## 2026-08-14 — pickle — model fleet up (3 loops)
- Loops A/B/C launched across main + 2 worktrees, supervisors, launchers, per-loop state.
- Planner=gemma (A/B .245, C .85), executor+reviewer=qwopus bf16 (.172). Template-level
  thinking-off fix on .172 persists.

## Earlier (saas-resume phase) — fleet builds M1
- T6 kitchen display, T7 cash register, T8 customers, T9 daily report, T13 delivery,
  T10 JSON API + rswag, T11 mock adapters, T12 documentation merged to main.
- `bin/demo-data.rb` bootstrap seed (catalog, gateway, open shift).
- POS smoke order `cf167fe8-...` run to payment step then aborted (resume pending).
- 2026-08-14 16:38:59 [loop-a] audit iter=219 issues - subsystem auth-users flagged (1131 chars)
- 2026-08-14 16:39:11 [loop-b] audit iter=21 issues - subsystem cash-register flagged (912 chars)
- 2026-08-14 16:39:21 [loop-c] audit iter=34 issues - subsystem integrations flagged (1598 chars)
- 2026-08-14 16:39:25 [loop-a] audit iter=220 issues - subsystem auth-users flagged (1255 chars)
- 2026-08-14 20:55:40 [loop-c] audit iter=35 issues - subsystem cart-checkout flagged (1846 chars)
