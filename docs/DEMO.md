# Client Demo — FoodTruck Ops runbook

A step-by-step script for showing the product to a prospective client. The demo
is seeded and self-contained: one restaurant ("FoodTruck Ops"), three staff
roles, a live queue of orders, and a kitchen display that reacts in real time.

**Estimated runtime: 20 minutes.** Everything runs locally with Docker on port
3000 — no external accounts, no internet needed, no real payments.

---

## 1. Prepare the machine (10 min before the call)

```bash
# from the repo root
bin/setup            # builds images, boots db/redis/web/worker/tailwind
bin/rails db:seed    # creates the business + 3 staff users
bin/rails runner bin/demo-data.rb   # seeds catalog, open shift, 6 live orders
```

The seed scripts are idempotent — re-running them never duplicates data.

**Check the landing page** before the client joins:

```bash
curl http://localhost:3000/up        # expect {"status":"ok"} (200)
```

## 2. The story in one line

> "This is the operating system for a single food truck or small restaurant:
> the cashier takes orders on a touchscreen, the kitchen sees them instantly on
> a big display, and the owner closes the day with a one-click report — all
> multi-tenant, so every restaurant gets its own sealed data."

## 3. Demo accounts (all passwords `password123`)

| Role    | Email                     | What they can show |
|---------|---------------------------|--------------------|
| Cashier | `cashier@foodtruck.local` | POS, checkout/payment, orders, customers |
| Kitchen | `kitchen@foodtruck.local` | Kitchen display (live queue) |
| Owner   | `owner@foodtruck.local`   | Dashboard, orders, staff, settings, cash register, daily report, menu |

Open three browser windows side by side (cashier + kitchen + owner) so the
client sees the order **flow** from one screen to the next live.

## 4. The walkthrough (15 min)

### Act 1 — The dashboard (owner) · 2 min
Log in as **owner**. Point at the four cards: today's gross, today's order
count, active orders, and the open cash-register shift banner. This is the
"owner answers the phone" view — everything a business owner checks first thing.

### Act 2 — Take an order (cashier) · 4 min
1. Log in as **cashier** in a second window. Note the open-shift prompt is
   already satisfied (the demo opened a shift with R$ 100,00 float).
2. Open **POS** (`/pos`). The seeded menu shows *Lanches*: X-Burger R$ 28,90,
   Batata Frita R$ 15,00, Suco de Laranja R$ 9,50.
3. Tap an item → it lands in the cart with the subtotal updating live.
4. **Add a customer**: either pick *Maria Silva* from the list or type a name
   to quick-create one. (Emphasize: no waiting to look up customers.)
5. Hit **Confirmar** → the order is confirmed and you land on the **checkout**
   screen with the amount due.

### Act 3 — It shows up in the kitchen instantly (kitchen) · 3 min
1. Look at the **kitchen** window (already logged in as `kitchen@foodtruck.local`,
   `/kitchen`). The order you just confirmed appears on the rail — with a
   live count-up prep timer.
2. Click **Iniciar preparo** → the timer starts; the order stays on the rail.
3. Click **Marcar pronto** → the order moves to the *Concluídos* rail below.
   The client just watched a full order lifecycle on two screens, no refresh.

### Act 4 — The seeded queue tells the whole day's story · 3 min
The seed planted orders in **every** state, so each screen is already alive:
- **Orders** (`/orders`, cashier): list with status badges.
- **Checkout** (`/checkout/:id`): the partially-paid order shows its payment
  history and remaining balance; the awaiting-payment one shows a recommended
  first amount.
- **Kitchen delivery rail**: the seeded *delivery* order shows **Maria Silva's
  address** (Rua Augusta, 455 — Consolação, São Paulo) right on the ticket, so
  kitchen staff routes it without leaving the screen.
- **Customers** (`/customers`, cashier): Maria Silva has her order history.

### Act 5 — Close the day (owner) · 3 min
1. As **owner**, open **Caixa** (`/cash_registers`) → the open shift shows
   entries as orders were paid.
2. Open **Relatório diário** (`/daily_report`) → gross, order count, and the
   breakdown. This is the "close of business" moment.
3. Bonus if time: **Menu** (`/categories`) to show the back-office catalog
   editor, and **Colaboradores** to show staff/roles management.

## 5. Optional teases (only if the client is technical)

- **JSON:API** at `/api-docs` (Swagger UI) — the entire POS as a REST API with
  bearer-token auth; the demo config enables a **mock payment gateway**, so
  checkout runs end-to-end without any real provider.
- **Real-time**: orders broadcast over Turbo Streams — no page reloads anywhere.
- **Multi-tenant**: every restaurant's data is sealed by Postgres Row-Level
  Security (RLS) — no cross-tenant leaks possible.

## 6. Troubleshooting during a demo

| Symptom | Fix |
|---|---|
| `localhost:3000` won't load | `docker compose --profile dev ps` — are `web`, `worker`, `tailwind` up? Re-run `bin/setup`. |
| Pages render without styling | Tailwind watcher died → `docker compose --profile dev up -d tailwind`. |
| Empty kitchen / empty orders | Demo data missing → re-run `bin/rails runner bin/demo-data.rb`. |
| Password rejected | All seeded users use `password123`; change via `OWNER_PASSWORD` on reseed. |
| I broke the demo data | The DB is disposable: `docker compose down -v` wipes it, then `bin/setup` + reseed. |

## 7. Rehearsal checklist

- [ ] `bin/setup` green and `curl /up` returns 200
- [ ] Seeded (db:seed + demo-data.rb) — dashboard shows non-zero cards
- [ ] 3 windows open: owner, cashier, kitchen — each logged in
- [ ] Sound toggle on kitchen tested (button top-right of `/kitchen`)
- [ ] Speak the one-line story from §2 before touching a button
