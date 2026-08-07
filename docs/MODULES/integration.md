# Integration Module — PLANNED

> **Status: planned.** This module does **not** exist on `main`. It is the
> design intent for the integration adapters ticket (T11, branch
> `t12-mock-adapters`). Nothing below is implemented yet — verify against the
> branch before relying on it.

## Design intent

- Provide a pluggable adapter pattern for external services (payment gateway,
  delivery, notifications)
- Ship **mock adapters** implementing the same contracts for development and
  tests
- Select adapters per business through integration settings (enabled flag +
  encrypted credentials)
- Keep the rest of the app decoupled from any concrete provider

## Intended shape

```text
app/integrations/
  payment_gateway.rb        # provider interface (authorize/capture/refund/status)
  mock_payment_gateway.rb   # deterministic sandbox "Pix/card" lifecycle
  delivery_service.rb       # interface
  mock_delivery_service.rb  # simulated dispatch
  ...
```

Adapters are selected per business via an `integration_settings`-style table
(enabled flag, encrypted credentials), and all third-party access goes through
these interfaces only — no direct SDK calls in controllers or services.

## Security expectations

- Encrypted credentials (Rails credentials/encrypted columns)
- Tenant-scoped settings
- Audit logging of adapter calls
- Mock adapters used in all specs

## Integration with the plan

Payments are currently recorded in-app (`Payment` with `method: cash|pix|card`
and a `gateway_reference` column). The adapter layer (T11) is where real
gateway calls will slot in behind `OrderLifecycle#record_payment!`.
