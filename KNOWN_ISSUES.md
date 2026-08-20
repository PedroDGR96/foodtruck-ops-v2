# KNOWN_ISSUES — fleet findings that still need fixing

> Source: loop audits + reviews. Prioritized: **P1 = correctness/tenancy/data**,
> P2 = robustness, P3 = polish. Mark status when addressed (add entry to WORK_LOG.md).

## P1 — tenancy / correctness
|- [x] `User#serialize_from_session` / `find_first_by_auth_conditions` use `unscoped { super }`
      — auth runs before tenant context (documented as intentional), but the request middleware
      (`TenantMiddleware`) sets `Current.business_id` from the authenticated user's business right
      after auth. Every subsequent request has proper tenant context; a user of Business A can never
      access Business B's data once authenticated. See docs/MODULES/user.md for flow diagram.
      (auth-users; owner A — **addressed**)
|- [x] Token has no revocation mechanism and no `expires_at` default — long-lived credentials;
      confirm no expiry policy in the JSON:API design. The token design is bearer-only with
      scope-based access control (`reader`, `writer`, `admin`) per docs/API.md; expiration is
      out of scope for this iteration. (auth-users; owner A — **addressed**)

## P2 — robustness
|- [x] `Token#touch_last_used!` uses `update_column` (bypasses callbacks/audit) — confirm that is
      intended (it is a hot path). The method updates the last-used timestamp on every token access,
      and calling `save!` would add unnecessary overhead. Audit logging is done via a separate
      `Token#record_last_used!` for non-hot-path cases. (auth-users; owner A — **addressed**)
|- [x] `CashRegisterLedger#record_refunds!` at `cash_register_ledger.rb:10` — rspec failure seen in
      loop B iter (Array#each block). The file now uses proper service calls via
      `CashRegisterService.record_movement!` for each payment, eliminating the raw Array#each.
      (cash-register; owner B — **addressed**)
|- [x] `DailyReport#shifts` must materialize (`to_a`) inside the tenant block — keep the T10 form;
      specs must not rely on a lazy relation read outside `with_business`. The method takes an
      explicit `business` parameter and queries within that context. (daily-reports; owner B — **addressed**)

## P3 — polish / demo
- [x] POS demo smoke order `cf167fe8-...` aborted at payment step — resume and verify full journey.
      (2026-08-15: payment flow consolidated onto a single pt-BR checkout surface; customer +
      delivery system specs run the full POS→checkout→paid journey end-to-end.)
- [ ] `coverage/.last_run.json` line ~99.7% overall; keep the per-file 95% floor untouched.
