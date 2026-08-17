---
description: Reference for Poly::Owners, the poly_owner macro that stamps a resource's root owner onto a polymorphic belongs_to at write time.
---

# Owners

## The mechanism

`Poly::Owners` is an `ActiveSupport::Concern`. Including it into a model adds
the class method `poly_owner`, which declares write-time owner stamping on a
polymorphic `belongs_to`, applied via a `before_validation` callback:

```ruby
class Coin < ApplicationRecord
  belongs_to :ledger
  belongs_to :resource, polymorphic: true

  include Poly::Owners

  poly_owner :resource, owner: -> { ledger&.account }
end
```

This matches the dummy schema's `coins` table (`spec/spec_helper.rb`), which
has nullable `owner_id`/`owner_type` columns, and the working `Coin` model
shown above (also from `spec/spec_helper.rb`).

## Signature

```ruby
poly_owner(assoc_name, owner:, type_column: :owner_type, id_column: :owner_id, allow_nil: true, immutable: false)
```

- `assoc_name` — the polymorphic association being stamped (e.g. `:resource`).
- `owner:` — required, no default. Resolves to the owner at write time; see
  "Resolving the owner" below for the three accepted forms.
- `type_column:` / `id_column:` — default to `:owner_type` / `:owner_id`, and
  name the columns written to.
- `allow_nil:` — defaults to `true`. Controls whether a `nil`-resolved owner
  clears the columns or raises. See "Failure modes" below.
- `immutable:` — defaults to `false`. Adds an `on: :update` validation, same
  pattern as `Poly::Role`'s `immutable:` option. See "Immutability" below.

## Association guard

`poly_owner` requires `assoc_name` to already be declared as
`belongs_to ..., polymorphic: true` on the class. Both a missing association
and a non-polymorphic/non-`belongs_to` association raise `ArgumentError` at
macro-declaration time, sourced from `spec/models/poly/owners_spec.rb`'s
"association validation" examples:

```ruby
class BadAssocCoin < ApplicationRecord
  self.table_name = 'coins'
  belongs_to :ledger
  include Poly::Owners

  poly_owner :ledger, owner: -> { ledger&.account }
end
# => ArgumentError: BadAssocCoin must declare belongs_to :ledger, polymorphic: true
```

The exact message is:

```
"#{name} must declare belongs_to :#{assoc_name}, polymorphic: true"
```

## Resolving the owner

The `owner:` value is resolved inside the `before_validation` callback, one
of three ways depending on its type. Each form is sourced from a real
`spec/models/poly/owners_spec.rb` example:

- **Proc** — evaluated via `record.instance_exec(&owner)`, e.g.
  `poly_owner :resource, owner: -> { ledger&.account }` (the `Coin` model's
  own declaration, shown above).
- **Symbol** (or `String`) — called as a method on the record via
  `record.public_send(owner)`, e.g. `poly_owner :resource, owner: :ledger`
  (from the "assigns owner from a Symbol method name" example, stubbed as
  `SymbolOwnerCoin`).
- **A direct value** — anything not a `Proc`, `Symbol`, or `String` is used
  as-is, e.g. `poly_owner :resource, owner: account` where `account` is an
  already-created `Account` instance (from the "assigns owner from a direct
  ActiveRecord instance" example, stubbed as `DirectOwnerCoin`).

## Write-time stamping

When resolution yields a persisted `ActiveRecord::Base`, `type_column` is set
to `resolved.class.base_class.name` and `id_column` to `resolved.id`. For
`Coin`, a resolved `Account` sets `owner_type` to `"Account"` and `owner_id`
to the account's id. Sourced from the "assigns owner_type and owner_id before
validation from owner proc" example:

```ruby
coin = create(:coin)
coin.valid?

coin.owner_type # => "Account"
coin.owner_id   # => coin.ledger.account.id
```

## Failure modes

`Poly::Owners` raises `ArgumentError` in every failure case — never a
different exception class. Each of these is a real example from
`spec/models/poly/owners_spec.rb`:

- **`owner:` omitted or explicitly `nil`** at macro-declaration time — raises
  immediately with message `"owner is required"` (sourced from the "raises
  when owner option is missing" example).
- **Resolved owner is not persisted** (`resolved.persisted?` is `false`) —
  raises during `before_validation` with message `"owner must be persisted"`
  (sourced from the "raises when the owner is not persisted" example).
- **Resolved owner is neither `nil` nor an `ActiveRecord::Base`** (e.g. a
  Proc returning a `String`) — raises during `before_validation` with
  message `"owner must resolve to an ActiveRecord::Base, got #{resolved.class}"`
  (sourced from the "raises when owner resolves to a non-active-record
  value" example).
- **Resolved owner is `nil` and `allow_nil: false`** — raises during
  `before_validation` with message `"owner resolved to nil"` (sourced from
  the "raises when owner resolves to nil and allow_nil is false" example).
  Contrast this with the default `allow_nil: true` behavior below, where a
  `nil`-resolved owner clears the columns instead of raising.

## Clearing on nil (`allow_nil: true`)

When the owner resolves to `nil` and `allow_nil` is left at its default
(`true`), `type_column` and `id_column` are both set to `nil` rather than
raising. Sourced from the "clears owner columns when owner resolves to nil"
example:

```ruby
ledger = build(:ledger, account: nil)
coin = build(:coin, ledger: ledger, owner_type: 'Account', owner_id: 10)

coin.valid?

coin.owner_type # => nil
coin.owner_id   # => nil
```

## Immutability

Passing `immutable: true` adds an `on: :update` validation that rejects
changing the owner once the record has been created — the same pattern as
`Poly::Role`'s `immutable:` option (fires on update only, not create).
Sourced from the "prevents owner changes on update when immutable: true"
example:

```ruby
class ImmutableCoin < ApplicationRecord
  self.table_name = 'coins'
  belongs_to :ledger
  belongs_to :resource, polymorphic: true
  include Poly::Owners

  poly_owner :resource, owner: -> { ledger&.account }, immutable: true
end

coin = ImmutableCoin.create!(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')
coin.ledger = create(:ledger)

coin.valid? # => false
```

Reassigning `ledger` changes what the `owner:` proc resolves to, which is
what the update-time validation rejects.

## Working example

Built on the real `Coin` model (`spec/spec_helper.rb`) and the `:coin` /
`:ledger` / `:account` factories (`spec/factories/coins.rb`,
`spec/factories/ledgers.rb`, `spec/factories/accounts.rb`):

```ruby
coin = create(:coin)
coin.valid?

coin.owner_type # => "Account"
coin.owner_id   # => coin.ledger.account.id
```

`:coin` builds a `:ledger` (which in turn builds an `:account`) and a
`resource factory: %i[post]` with `resource_role { 'primary' }`. `Coin`'s
`poly_owner :resource, owner: -> { ledger&.account }` declaration resolves
the owner through the ledger to its account, so the row's `owner_type` /
`owner_id` end up pointing at that account rather than at the ledger or the
polymorphic `resource` itself.

## Next Steps

Continue with [Stack](./stack) for a role-discriminated, prime-tracked audit
trail on top of a polymorphic `belongs_to`.

[Home](./) · Back to [Role](./role)
