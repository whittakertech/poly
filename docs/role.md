---
description: Reference for Poly::Role, the poly_role macro that gives a polymorphic belongs_to a normalized, validated role column and a for_role scope.
---

# Role

## The mechanism

`Poly::Role` is an `ActiveSupport::Concern`. Including it into a model adds
the class method `poly_role`, which declares a role column on a polymorphic
`belongs_to`:

```ruby
class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  include Poly::Role

  poly_role :taggable
end
```

Calling `poly_role :taggable` expects a `taggable_role` column — the macro
derives the column name as `:"#{assoc_name}_role"`. This matches the dummy
schema's `taggings` table (`spec/spec_helper.rb`), which has a non-null
`taggable_role` string column, and the `Tagging` model shown above (also from
`spec/spec_helper.rb`).

## Signature

```ruby
poly_role(assoc_name, max_length: 64, immutable: false)
```

- `assoc_name` — the polymorphic association the role column belongs to
  (e.g. `:taggable`); the role column is `:"#{assoc_name}_role"`.
- `max_length:` — the maximum length allowed for the role value. Defaults to
  `64` and drives the length validation described below.
- `immutable:` — when `true`, adds an `on: :update` validation that rejects
  changing the role column on an existing record. Defaults to `false`. See
  "Immutability" below.

## Normalization

Before validation, the role value is stripped of leading/trailing whitespace
and downcased. Sourced from `spec/models/poly/role_spec.rb`'s "normalization"
examples:

```ruby
tagging = build(:tagging, taggable_role: '  My_Role  ')
tagging.valid?

tagging.taggable_role # => "my_role"
```

`'PRIMARY'` normalizes to `'primary'`, and `'  primary  '` normalizes to
`'primary'` the same way.

## Validation

Each of these is a real example from `spec/models/poly/role_spec.rb`:

- **Presence** — a blank or `nil` role fails validation:

  ```ruby
  tagging = build(:tagging, taggable_role: nil)

  tagging.valid? # => false
  tagging.errors[:taggable_role] # => ["can't be blank"]
  ```

- **Format** — restricted to `/\A[a-z0-9_]+\z/`: lowercase letters, digits,
  and underscores only. `'my role'` (a space) and `'role-name'` (a hyphen)
  both fail as `"is invalid"`; `'role_123'` is valid.

- **Length** — capped at `max_length`. Under the default `max_length: 64`, a
  65-character value fails with an error matching `"too long"`, while
  exactly 64 characters is valid.

## The `for_role` scope

`Model.for_role(role)` returns records whose role column equals the
normalized (stripped + downcased) input:

```ruby
tagging = create(:tagging, taggable_role: 'primary')

Tagging.for_role('  PRIMARY  ') # => contains `tagging`
Tagging.for_role('nonexistent') # => empty relation
```

Because the input is normalized the same way the column is, `for_role`
matches regardless of the case or surrounding whitespace of the value passed
in.

## Immutability

Passing `immutable: true` adds a validation that only runs `on: :update`,
rejecting any change to the role column after the record has been created:

```ruby
class ImmutableTagging < ApplicationRecord
  self.table_name = 'taggings'
  belongs_to :taggable, polymorphic: true
  include Poly::Role

  poly_role :taggable, immutable: true
end

tagging = ImmutableTagging.create!(taggable: create(:post), taggable_role: 'primary')
tagging.taggable_role = 'secondary'

tagging.valid? # => false
```

Note that this only fires on `update` — the role can still be set freely at
`create` time.

## Working example

Built on the real `Tagging` model (`spec/spec_helper.rb`) and the `:tagging`
factory (`spec/factories/taggings.rb`, which builds a `taggable factory:
%i[post]` with `taggable_role { 'primary' }`):

```ruby
tagging = build(:tagging, taggable_role: 'Primary')
tagging.valid?
tagging.taggable_role # => "primary"

matched = create(:tagging, taggable_role: 'primary')
Tagging.for_role('  PRIMARY  ') # => contains `matched`
```

## Next Steps

Continue with [Owners](./owners) to project a resource's root owner onto the
row itself.

[Home](./) · Back to [Joins](./joins)
