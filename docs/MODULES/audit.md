# Audit Module

Append-only audit trail for security-relevant and money events.

## Purpose

- Records sign-in/out/failure and account lock events
- Records every order transition on the `order_events` timeline
- Provides a tenant-scoped, RLS-protected trail for forensics and support

## Key model

`AuditLog` (app/models/audit_log.rb) — includes `BusinessScoped`.

**Fields:** `action`, `resource`, `resource_id` (optional), `actor_id`
(optional), `metadata` (jsonb), `created_at`, `updated_at`.

**Record helper:**

```ruby
AuditLog.record!(
  action: "failed_sign_in",
  resource: "user",
  resource_id: user.id,
  actor_id: user.id,
  metadata: { ip: request.remote_ip }
)
```

## Actions recorded today

| Area | Actions |
|------|---------|
| Authentication | `sign_in`, `sign_out`, `failed_sign_in` |
| Account lifecycle | `user_locked`, `user_unlocked` (`User#record_lock_change`) |
| Orders | the `order_events` timeline (`confirmed`, `paid`, `cooking_started`, `ready`, `completed`, `cancelled`, `refunded`, `discarded`, `partially_paid`) |

Order history is intentionally stored on `order_events` (per-order, immutable,
with the acting user and metadata) rather than in `audit_logs`; `audit_logs`
holds cross-cutting security events.

## Policies

- **Append-only:** create-only. Never update or delete audit rows.
- **Tenant-scoped:** every row carries `business_id` and is covered by RLS.
- **Actor optional:** some system events have no user; sign-in events always
  carry the actor id.

## Retention

No automatic archival is implemented. Retain per your compliance policy; any
future cleanup job must operate through `Tenancy.with_business` and never
violate the append-only rule.

## Factories

```ruby
factory :audit_log do
  action { "sign_in" }
  resource { "session" }
  business
end
```
