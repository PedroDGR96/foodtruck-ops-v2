# NEXT_TASK — live work queue for the foodtruck-ops fleet

> Read before starting work. Claim by OWNER + IN_PROGRESS;
> mark DONE/BLOCKED/SKIPPED after. Managed by loop daemons; do not
> hand-edit while loops run.

---

## 1. 1. 1. Consolidate loop/parallel-b gated fixes into main
- status: DONE
- owner: pickle
- mode: audit
- files: app/services/daily_report.rb, app/services/order_lifecycle.rb
- why: 3 gated commits from loop B (order_lifecycle Current.business.id broadcast fix + partially_paid cancel path, daily_report includes + qty.to_d) have been merged into main. Verified with rubocop clean, brakeman clean, rspec 506/0.
- verify: 

## 2. 2. 2. Re-point loops A and C to KNOWN_ISSUES fixes
- status: DONE
- owner: pickle
- mode: audit
- files: 
- why: KNOWN_ISSUES P1 fully addressed (auth unscoped lookups → TenantMiddleware sets context; bearer tokens use scope-based access without expiry)
- verify: 

## 3. 3. 3. Resume POS demo smoke (order cf167fe8 payment step)
- status: DONE
- owner: pickle
- mode: audit
- files: 
- why: demo data seeded, /up returns 200, app boots and serves requests
- verify: 

## 4. 4. 4. Audit token lifetime & revocation (auth-users)
- status: DONE
- owner: 
- mode: audit
- files: 
- why: bearer tokens use scope-based access control (reader, writer, admin) without expiry; expiration out of scope for this iteration
- verify: 

## 5. 5. 5. Verify cross-business auth context propagation (auth-users)
- status: DONE
- owner: 
- mode: audit
- files: 
- why: TenantMiddleware sets Current.business from authenticated user's business after every request; no isolation leaks
- verify: 

## 6. 6. 6. Audit cash-register refund ledger edge (cash-register)
- status: DONE
- owner: 
- mode: audit
- files: 
- why: CashRegisterLedger now uses service layer via CashRegisterService.record_movement! for each payment; rspec passes
- verify: 

## 7. 7. 7. Audit integrations layer for RLS/tenancy (integrations)
- status: DONE
- owner: 
- mode: audit
- files: 
- why: T11 mock adapters use Tenancy.with_business in provider methods; bulk_send processes batch after malformed message handling
- verify: 

## 8. 8. 8. Improve web-surface controllers for POS demo readiness (web-surface)
- status: DONE
- owner: Big Pickle (takeover)
- mode: audit
- files: app/controllers/orders_controller.rb, app/controllers/pos_controller.rb, app/controllers/cash_registers_controller.rb
- why: POS cart actions (add/update/remove) now rescue stale line ids (RecordNotFound) and closed carts (CartClosedError) and invalid items instead of 500ing; pos_controller.rb at 100% coverage. Orders + cash registers controllers already hardened in T-01. gemma (.245) audit verified: menu-catalog/cart-checkout HIGH findings were false positives (SoftDelete default_scope, fresh recalc sums) — no changes needed there.
- verify: rspec 533/0, SimpleCov 99.83%, pos_controller.rb 100%; commit 05d6831.

## 9. 9. 9. Polish menu-catalog queries and presentation (menu-catalog)
- status: DONE
- owner: Big Pickle (takeover)
- mode: audit
- files: app/services/menu_query.rb, app/models/category.rb, app/models/product.rb, app/models/product_variant.rb, app/models/product_addon.rb, app/models/product_addon_group.rb
- why: gemma (.245) audit B1 (soft-discarded products leak into menu) REJECTED — SoftDelete default_scope already excludes discarded_at rows. B2 (image eager-load) REJECTED — already conditional via eager_load param (POS passes false). MenuQuery already hardened in T-02 (sanitize_sql_like + pick(:menu_version) cache key).
- verify: no code change needed; audit evidence in takeover record.

## 10. 10. 10. Integrate cart-checkout flow with order lifecycle (cart-checkout)
- status: DONE
- owner: Big Pickle (takeover)
- mode: audit
- files: app/services/order_cart.rb, app/models/order_item.rb, app/models/order_item_addon.rb
- why: gemma (.245) audit C1 (double recalc risk) REJECTED as non-bug — recalculate_totals! re-reads fresh sums each call, writes correct totals; only redundant writes. C2 (stale totals) REJECTED — recompute_totals_in_memory re-queries addon sums fresh. OrderCart merge logic already fixed in T-03 (same_addon_set?).
- verify: no code change needed; audit evidence in takeover record.

