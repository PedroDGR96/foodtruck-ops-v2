# Menu Module

The product catalog: categories → products → variants and add-on groups/add-ons.

## Purpose

- Organizes products into categories (positioned)
- Handles product variants (e.g. sizes) and add-on groups (e.g. "extras")
- Caches the POS menu with tenant-aware invalidation
- Supports product images via ActiveStorage

## Key models

| Model | Belongs to | Key fields | Notes |
|-------|-----------|------------|-------|
| `Category` | `business` | `name`, `position`, `active` | unique `name` per business |
| `Product` | `business`, `category` | `name`, `description`, `price`, `status` (`available`/`unavailable`), `position` | `has_one_attached :image`; unique `name` per business |
| `ProductVariant` | `business`, `product` | `name`, `price` (nullable), `stock` (nullable) | `effective_price` = own price || product price |
| `ProductAddonGroup` | `business`, `product` | `name`, `multiple`, `min_select`, `max_select`, `position` | |
| `ProductAddon` | `business`, `product_addon_group` | `name`, `price` | unique `name` per group |

All menu models include `BusinessScoped`, `SoftDelete` (`discarded_at`) and
`MenuInvalidatable`.

## Hierarchy

```
Business
  └── Categories (positioned)
       └── Products (positioned)
            ├── ProductVariants (optional, sized)
            └── ProductAddonGroups (positioned)
                 └── ProductAddons
```

## Querying the menu

`MenuQuery` builds the POS menu: available products grouped by active category,
optional fast name search (`ILIKE`), eager-loaded variants/add-ons/image. The
cache key is tenant-aware and includes `business.menu_version`, which is
bumped by `MenuInvalidatable` on every menu write:

```ruby
MenuQuery.call(business: Current.business, query: params[:q])
```

## Cache invalidation

`MenuInvalidatable` bumps `businesses.menu_version` in an `after_commit` for
any write to a menu model, so the `Rails.cache` menu fragment key changes and
the menu is rebuilt on the next read.

## Soft delete

`discarded_at` + `default_scope` (via `SoftDelete`). `product.discard!`
removes it from the menu without losing order history; `restore!` brings it
back. Unique-name constraints are scoped per business/group/product but are
**not** discarded-filtered, so a discarded row still reserves its name (only
`customers.phone` has the `discarded_at IS NULL` partial-unique exception).

## Controllers & policies

`CategoriesController` and `ProductsController` (plus nested variants/add-ons)
authorize through `MenuRecordPolicy`: index/show for all staff, create/update/
destroy for owners only.

## Factories

```ruby
factory :category do
  name { "Bebidas" }
  business
end

factory :product do
  name { "Coxinha" }
  price { 8.50 }
  status { "available" }
  category
  business
end
```
