# Cash Register Module — PLANNED

> **Status: planned.** This module does **not** exist on `main`. It is the
> design intent for the cash register ticket (T7, branch `t7-cash-register`).
> Nothing below is implemented yet — verify against the branch before relying
> on it.

## Design intent

- Track the business's daily cash movements (open/close register, cash in/out,
  sales count, per-method totals)
- Record each payment method (`cash`, `pix`, `card`) per register session
- Support `z`-report style closing: declared vs. expected cash difference
- Surface as a manager/owner-only area (staff view is limited)

## Intended shape

A `cash_register`/`register_session`-style model scoped to a business, with
money entries referencing the originating `Payment`/`Order`, reconciled at
close:

```text
RegisterSession          # business, opened_by, opened_at, closed_by, closed_at
  ├─ RegisterMovement    # cash in/out, amount, note
  └─ (payments logged)   # totals by method at close
```

Closing computes expected totals from recorded payments and flags the declared
difference for the owner.

## Integration with the plan

- Builds on the Order/Payment models already on `main`
- The Daily Report (T10) will aggregate register data for the shift summary
- The Kitchen Display System (T6) is independent of this module
