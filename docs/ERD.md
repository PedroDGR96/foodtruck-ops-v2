# Entity Relationship Diagram

The schema below is generated from the actual `db/structure.sql` (the project
uses `config.active_record.schema_format = :sql`). Tenant-scoped tables carry a
`business_id uuid NOT NULL` foreign key to `businesses`, `FORCE ROW LEVEL
SECURITY`, a `tenant_isolation` policy, and a `BEFORE INSERT` trigger that fills
`business_id` from the `app.business_id` GUC. See TENANCY.md for how the layers
interact.

## Entities

```mermaid
erDiagram
    businesses ||--o{ users : "has many"
    businesses ||--o{ categories : "has many"
    businesses ||--o{ customers : "has many"
    businesses ||--o{ orders : "has many"
    businesses ||--o{ audit_logs : "has many"

    categories ||--o{ products : "has many"
    products ||--o{ product_variants : "has many"
    products ||--o{ product_addon_groups : "has many"
    product_addon_groups ||--o{ product_addons : "has many"

    orders ||--o{ order_items : "has many"
    orders ||--o{ payments : "has many"
    orders ||--o{ order_events : "has many"
    order_items ||--o{ order_item_addons : "has many"

    customers ||--o{ orders : "has many"
    users ||--o{ orders : "created by"

    businesses {
        uuid id PK
        varchar name
        jsonb settings "default: {}"
        varchar currency "default: BRL"
        varchar timezone "default: America/Sao_Paulo"
        boolean active "default: true"
        timestamp discarded_at
        integer menu_version "default: 0"
        timestamp created_at
        timestamp updated_at
    }

    users {
        uuid id PK
        uuid business_id FK
        varchar name
        varchar email "unique"
        varchar role "owner|cashier|kitchen"
        varchar encrypted_password
        varchar reset_password_token "unique"
        timestamp reset_password_sent_at
        integer sign_in_count "default: 0"
        timestamp current_sign_in_at
        timestamp last_sign_in_at
        varchar current_sign_in_ip
        varchar last_sign_in_ip
        integer failed_attempts "default: 0"
        varchar unlock_token "unique"
        timestamp locked_at
        boolean active "default: true"
        timestamp created_at
        timestamp updated_at
    }

    categories {
        uuid id PK
        uuid business_id FK
        varchar name "unique per business"
        integer position "default: 0"
        boolean active "default: true"
        timestamp discarded_at
        timestamp created_at
        timestamp updated_at
    }

    products {
        uuid id PK
        uuid business_id FK
        uuid category_id FK
        varchar name "unique per business"
        text description
        decimal price "decimal(12,2)"
        varchar status "available|unavailable"
        integer position "default: 0"
        timestamp discarded_at
        timestamp created_at
        timestamp updated_at
    }

    product_variants {
        uuid id PK
        uuid business_id FK
        uuid product_id FK
        varchar name "unique per product"
        decimal price "decimal(12,2), nullable"
        integer stock "nullable"
        boolean active "default: true"
        timestamp discarded_at
        timestamp created_at
        timestamp updated_at
    }

    product_addon_groups {
        uuid id PK
        uuid business_id FK
        uuid product_id FK
        varchar name
        boolean multiple "default: true"
        integer min_select "default: 0"
        integer max_select "nullable"
        integer position "default: 0"
        boolean active "default: true"
        timestamp discarded_at
        timestamp created_at
        timestamp updated_at
    }

    product_addons {
        uuid id PK
        uuid business_id FK
        uuid product_addon_group_id FK
        varchar name "unique per group"
        decimal price "decimal(12,2)"
        boolean active "default: true"
        timestamp discarded_at
        timestamp created_at
        timestamp updated_at
    }

    customers {
        uuid id PK
        uuid business_id FK
        varchar name
        varchar phone "unique per business, not soft-deleted"
        varchar whatsapp
        date birthday
        text notes
        timestamp discarded_at
        timestamp created_at
        timestamp updated_at
    }

    orders {
        uuid id PK
        uuid business_id FK
        uuid user_id FK "cashier, nullable"
        uuid customer_id FK "nullable"
        varchar order_type "local|delivery|pickup, default local"
        varchar status "draft|open|partially_paid|paid|in_kitchen|ready|completed|cancelled|refunded"
        varchar kitchen_status "pending|in_progress|done"
        varchar payment_status "pending|partially_paid|paid|refunded"
        decimal subtotal "decimal(12,2)"
        decimal tax "decimal(12,2)"
        decimal total "decimal(12,2)"
        text notes
        integer lock_version "optimistic locking, default: 0"
        timestamp created_at
        timestamp updated_at
    }

    order_items {
        uuid id PK
        uuid business_id FK
        uuid order_id FK
        uuid product_id FK "nullable"
        uuid product_variant_id FK "nullable"
        varchar product_name "snapshot"
        varchar variant_name "snapshot, nullable"
        decimal unit_price "decimal(12,2)"
        integer quantity "default: 1"
        decimal line_total "decimal(12,2)"
        timestamp created_at
        timestamp updated_at
    }

    order_item_addons {
        uuid id PK
        uuid business_id FK
        uuid order_item_id FK
        uuid product_addon_id FK "nullable"
        varchar name "snapshot"
        decimal price "decimal(12,2)"
        timestamp created_at
        timestamp updated_at
    }

    payments {
        uuid id PK
        uuid business_id FK
        uuid order_id FK
        varchar method "cash|pix|card"
        decimal amount "decimal(12,2)"
        varchar status "succeeded|refunded, default succeeded"
        varchar gateway_reference "nullable"
        timestamp created_at
        timestamp updated_at
    }

    order_events {
        uuid id PK
        uuid business_id FK
        uuid order_id FK
        uuid user_id FK "actor, nullable"
        varchar event "immutable timeline"
        jsonb metadata "default: {}"
        timestamp created_at
    }

    audit_logs {
        uuid id PK
        uuid business_id FK
        varchar action
        varchar resource
        varchar resource_id "nullable"
        uuid actor_id "nullable"
        jsonb metadata "default: {}"
        timestamp created_at
        timestamp updated_at
    }
```

## RLS / soft-delete matrix

| Table            | `business_id` | RLS (FORCE + policy) | Soft delete | Notes |
|------------------|:---:|:---:|:---:|-------|
| `businesses`     | —   | No  | Yes | tenant root |
| `users`          | Yes | **No** | No  | scoped in-app only; auth needs `unscoped` lookups |
| `categories`     | Yes | Yes | Yes | |
| `products`       | Yes | Yes | Yes | |
| `product_variants` | Yes | Yes | Yes | |
| `product_addon_groups` | Yes | Yes | Yes | |
| `product_addons` | Yes | Yes | Yes | |
| `customers`      | Yes | Yes | Yes | |
| `orders`         | Yes | Yes | No  | |
| `order_items`    | Yes | Yes | No  | |
| `order_item_addons` | Yes | Yes | No | |
| `payments`       | Yes | Yes | No  | |
| `order_events`   | Yes | Yes | No  | immutable timeline |
| `audit_logs`     | Yes | Yes | No  | append-only |

Soft delete is implemented by the `SoftDelete` concern (`discarded_at` +
`default_scope`); discarded rows are excluded unless queried with `with_discarded`.

## Indexes

- `businesses`: `id` PK.
- `users`: unique `email`, unique `reset_password_token`, unique `unlock_token`,
  `business_id`.
- `categories`: unique `(business_id, name)`, `(business_id, position)`.
- `products`: unique `(business_id, name)`, `(category_id, position)`,
  `business_id`, `category_id`.
- `product_variants`: unique `(product_id, name)`, `business_id`, `product_id`.
- `product_addon_groups`: unique `product_id`+`position`, `business_id`,
  `product_id`.
- `product_addons`: unique `(product_addon_group_id, name)`, `business_id`,
  `product_addon_group_id`.
- `customers`: unique `(business_id, phone) WHERE phone IS NOT NULL AND
  discarded_at IS NULL`, `(business_id, name)`, `business_id`.
- `orders`: `business_id`, `(business_id, created_at)`, `(business_id, status)`,
  `(business_id, customer_id)`, `(business_id, user_id)`, `user_id`,
  `customer_id`.
- `order_items`: `business_id`, `order_id`, `(order_id, product_id)`,
  `product_id`, `product_variant_id`.
- `order_item_addons`: `business_id`, `order_item_id`, `product_addon_id`.
- `payments`: `business_id`, `order_id`.
- `order_events`: `business_id`, `order_id`, `(order_id, created_at)`, `user_id`.
- `audit_logs`: `business_id`, `(business_id, created_at)`, `action`.

## Constraints (CHECK)

- `orders`: `subtotal >= 0`, `tax >= 0`, `total >= 0`
- `order_items`: `quantity > 0`, `unit_price >= 0`, `line_total >= 0`
- `order_item_addons`: `price >= 0`
- `payments`: `amount >= 0`
- `products`: `price >= 0`
- `product_variants`: `price IS NULL OR price >= 0`
- `product_addons`: `price >= 0`
- `users`: `role IN ('owner','cashier','kitchen')`

Application-level validations additionally keep totals consistent
(`Order#recalculate_totals!` recomputes `subtotal`/`total` from line items and
add-ons, `total == subtotal + tax`) and payments from exceeding the order
balance (`Payment#cannot_exceed_order_balance`).

## ActiveStorage

`active_storage_attachments`, `active_storage_blobs` and
`active_storage_variant_records` are standard Rails tables (integer PKs) used
for product images (`Product.has_one_attached :image`).

## Migration versions

Schema migrations are recorded in `schema_migrations`; the full list is in
`db/structure.sql`. Notable migrations in the merged M1 history: multi-tenant
RLS foundation, Devise users, menu (categories/products/variants/add-ons),
orders/payments/events, and the customer registry.
