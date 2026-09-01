# PRIORITIES.md — Autonomous Loop Directives

## Current Phase: PROVE THE CORE FOOD-TRUCK WORKFLOW (the pilot)

The last phase (LGPD + feature expansion + KNOWN_ISSUES) is DONE — all queue items
are addressed and every KNOWN_ISSUES P1/P2 is closed. The loop was falling back to an
endless `operator-directives` audit because it had no real work. This phase points the
loop at the ONE thing that matters for the business: **can an operator actually run a
real service through this, end-to-end, on the worst night?**

Target slice (make it work, then make it survive failures):

```
MENU → CUSTOMER ORDER → ORDER CREATED → PAYMENT → POS/KITCHEN → PREPARATION
     → READY → COMPLETED → FINANCIAL RECONCILIATION → DAILY REPORT
```

Each directive below is concrete, file-targeted, and verifiable so the loop can land it.

---

## Priority 1: Business-invariant spec coverage (the "worst night" scenarios)

Add/strengthen SPECS (spec/ only) that pin the money-path invariants. These are
**acceptance scenarios, not line-coverage filler**. The 95% per-file floor stays, but
the goal here is *correctness*, so add specs that would catch a real business bug.

- `spec/services/order_lifecycle_spec.rb` — the payment concurrency invariant:
  - "two concurrent successful payments never double-settle" — payment_status stays
    `paid` with exactly ONE `paid` event; total payments never exceeds order.total.
  - "payment that would exceed order balance is rejected" (Payment#cannot_exceed_order_balance).
  - "a successful payment of exactly the balance marks order paid" — one transition, one event.
- `spec/services/cash_register_spec.rb` — drawer reconciliation:
  - "a cash payment on an open shift lands in that shift's drawer total".
  - "a cash refund creates exactly ONE expense movement tied to the original payment".
- `spec/services/daily_report_spec.rb` — financial reconciliation:
  - "a completed paid order appears in the day's revenue exactly once".
  - "a refunded order offsets the day's revenue without double-counting".
- `spec/integrations/` — duplicate/webhook/resilience:
  - "a duplicated external event is safe" (idempotency): processing the same
    payment/webhook twice yields one ledger movement, not two.
  - "a job retry does not duplicate a side effect".

## Priority 2: Kill the `operator-directives` audit fallback loop

The loop keeps flagging/auditing `operator-directives` with "best-effort patches
exhausted" and never retiring. This is wasted compute that stops real work.
- Locate the audit source that keeps generating `operator-directives` subsystem finds
  and either neutralize the false-positive find or mark it no-op **without touching
  PRIORITIES.md / NEXT_TASK.md semantics**. Prefer adding a spec that documents why the
  current operator-directives state is INTENTIONAL (so the audit has evidence to stop),
  rather than hacking loop.py.
- Target helpers: `app/`, `lib/`, `spec/` only. DO NOT hand-edit loop.py directives.

## Priority 3: Order historical accuracy (snapshot integrity)

Orders must retain correct historical info even if the product/price later changes.
- Verify/complete order-item **price snapshots** at order time: changing a Product price
  after an order is paid must NOT change that order's line totals.
- Add/strengthen specs in `spec/verticals/foodtruck/models/order_item_spec.rb` pinning:
  "an old order keeps its original line price after the product's price changes".

## Priority 4: Cart staleness & double-click safety

- Verify `order_cart.rb` rejects a stale cart (a product removed/deleted or a price
  changed mid-session) with a clear, surfaced message rather than a silent wrong order.
- Add specs for: deleted product in cart, price changed while cart open, duplicate
  "place order" click produces ONE order (idempotency key or transition guard).

---

## DEMO FREEZE (2026-09-01 → 2026-09-03, client presentation window)

STOP. A client demo/presentation is scheduled within 48h. During this window:

- **DO NOT modify `app/` behavior files** (`app/verticals/**`, `app/controllers/**`,
  `app/views/**`, `app/services/**`, `app/integrations/**`). The presentation screens
  must not change under the presenter.
- **Only allowed work in this window**: (a) ADD/DOCUMENT-only specs (`spec/**`) that
  prove existing behavior is intentional or pin invariants; (b) genuinely
  demo-blocking bug fixes — and even those go through manual review, never
  fast-landed.
- Audit findings from this window are to be COLLECTED and reported, not patched.
  Prefer marking findings as INTENTIONAL-with-spec over any `app/` change.
- Revert-for-safety: if the demo data (`bin/demo-data.rb`) or the running stack is
  disturbed, report it — do not "fix" it by patching app code.
- This freeze lifts automatically on 2026-09-03. Do NOT try to game it by editing
  this file's timestamp.

## Constraints (unchanged, hard rules)
- Run `bin/ci` (rubocop + brakeman + rspec + SimpleCov) after every change; land only if
  0 failures AND per-file coverage >= 95%.
- NEVER break existing tests.
- Only touch `app/ spec/ lib/` — schema/config/secrets (`db/structure.sql`, Gemfile,
  compose.yml, AGENTS.md, .simplecov) are FORBIDDEN to the loop.
- EXCLUDED from loop targets: `app/core/`, `spec/rls/`, `docker/`, `bin/`.
- FROZEN subsystems (never modify): tenancy, boundary-fence, security-fence.
- All tenant queries MUST be wrapped in `Tenancy.with_business(business)` — a read
  outside the block raises `uuid: ""` (RLS GUC). Materialize lazy relations inside.
- Prefer business-correctness specs over cosmetic refactors. DO NOT churn stable code —
  "I'd implement it differently" is NOT a reason to change it.
- garage-ops and medical-ops are NOT loop targets — manual fixes only.

## Phase exit criteria
This phase is DONE when, with the loop running unattended for a full night:
1. The MENU→ORDER→PAY→LEDGER→REPORT slice is covered by the business-invariant specs
   above AND they pass.
2. The `operator-directives` audit stops generating false-positive finds (or is
   documented intentional with a passing spec).
3. The loop lands at least the Priority-1/3/4 specs (or a reasoned equivalent) with
   `bin/ci` green.
