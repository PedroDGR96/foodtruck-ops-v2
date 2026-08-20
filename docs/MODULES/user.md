# User Module

Authentication (Devise), roles and user management, scoped per business.

## Purpose

- Manages user accounts inside a business
- Authenticates via Devise (session-based, no JWT)
- Enforces role-based authorization through Pundit
- Part of the tenancy flow (the signed-in user determines the tenant)

## Key model

`User` (app/models/user.rb) — includes `BusinessScoped`.

**Fields:** `name`, `email` (unique **globally** across all businesses,
case-insensitive), `role`
(`owner`/`cashier`/`kitchen`), `active`, Devise fields (`encrypted_password`,
`reset_password_token`, `sign_in_count`, `current_sign_in_at`/`ip`,
`last_sign_in_at`/`ip`, `failed_attempts`, `unlock_token`, `locked_at`),
`business_id`.

**Devise modules:** `database_authenticatable`, `validatable`, `timeoutable`
(2h), `lockable`, `trackable`.

**Tenancy note:** `User` includes `BusinessScoped`, so normal queries are
scoped to the current business; Devise authentication deliberately uses
`unscoped` lookups (`serialize_from_session`, `find_first_by_auth_conditions`)
so login can find a user before tenant context exists.

## Authentication flow

1. User POSTs credentials to `/users/sign_in`.
2. `Users::SessionsController#create` resolves the candidate business by email
   and wraps `warden.authenticate!` in `Tenancy.with_business(business)`.
3. On success the session is established and an `AuditLog` (`action: "sign_in"`,
   `metadata: { ip }`) is recorded inside the tenant.
4. Every subsequent request passes through `TenantMiddleware`, which sets
   tenant context from the warden user.
5. Failed logins are audited as `failed_sign_in`; lock/unlock as
   `user_locked`/`user_unlocked` (`config/initializers/auth_audit.rb`,
   `User#record_lock_change`).

## Authorization (Pundit)

Policies live in `app/policies/`. The role matrix:

| Surface | owner | cashier | kitchen |
|---------|:---:|:---:|:---:|
| POS / orders (create, pay) | ✓ | ✓ | ✗ |
| Orders view | ✓ | ✓ | ✓ |
| Customers (view / create / update) | ✓ | ✓ | ✗ |
| Customers archive | ✓ | ✗ | ✗ |
| Menu CRUD | ✓ | ✗ | ✗ |
| Users & settings | ✓ | ✗ | ✗ |

Shared rules: `MenuRecordPolicy` backs every menu resource (owner-only writes);
`OrderPolicy#cancel?` narrows to owner once an order is `paid`/`in_kitchen`/`ready`.

## Factories

```ruby
factory :user do
  name { "Caixa" }
  sequence(:email) { |n| "caixa#{n}@foodtruck.local" }
  role { "cashier" }
  password { "password123" }
  business
end
```

## Notes

- Seeds create `owner@`, `cashier@` and `kitchen@foodtruck.local` (password
  `password123` by default, override with `OWNER_PASSWORD`).
- The Kitchen Display System is a planned module; `kitchen` users will get
  their KDS surface once T6 lands.
