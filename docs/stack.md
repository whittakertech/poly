---
description: Reference for Poly::Stack, the poly_stack macro that builds a role-discriminated, prime-tracked audit trail of cards on top of a polymorphic belongs_to.
---

# Stack

## The mechanism

`Poly::Stack` is an `ActiveSupport::Concern` that `include`s `Poly::Role`.
Including it into a model and calling the class method `poly_stack` adds a
`prime` scope, a `before_create` callback (`poly_stack_seize_prime`), and an
`after_create` callback (`poly_stack_chain_superseded`) — matching the
working `Status` model in `spec/spec_helper.rb`:

```ruby
class Status < ApplicationRecord
  belongs_to :resource, polymorphic: true

  include Poly::Joins
  include Poly::Stack

  poly_stack :resource
end
```

`poly_stack(assoc_name, max_length: 64)` calls `poly_role(assoc_name,
max_length: max_length)` under the hood, so a stack inherits `Poly::Role`'s
role column and validation for free — a stack model needs a role column
(e.g. `resource_role`) just like a plain `Poly::Role` model does. On top of
that it adds `is_prime` (the enforced golden-child marker) and
`superseded_by_id` (an unconstrained audit edge). `Poly::Stack` is
deliberately payload agnostic: it does not define the payload column, the
actor, or the reason — those belong to the host model. Source calls each row
in the stack a **card** (`lib/poly/stack.rb`'s own terminology, not "entry").

This matches the dummy schema's `statuses` table (`spec/spec_helper.rb`),
which has `resource_type`/`resource_id`/`resource_role` columns, an
`is_prime` boolean (`null: false, default: false`), and a `superseded_by_id`
column.

## The Prime/Card Model

"Prime" is the single current card per `(resource, role)` where `is_prime` is
`true` — the top of the stack, reachable via the `prime` scope
(`where(is_prime: true)`). Sourced from `poly_stack_seize_prime` and
`poly_stack_chain_superseded` (`lib/poly/stack.rb`) and confirmed by the
"priming" and "supersession chain" examples in
`spec/models/poly/stack_spec.rb`:

- On `before_create`, `poly_stack_seize_prime` looks up the existing prime
  card scoped to the same polymorphic type/id/role, demotes it via
  `update_columns(is_prime: false)` if one exists, and sets the new record's
  `is_prime = true`.
- On `after_create`, `poly_stack_chain_superseded` links the demoted card's
  `superseded_by_id` to the new card's `id`.
- The newest card per `(resource, role)` is always prime: creating a third
  card demotes the second and promotes the third.

```ruby
create(:status, resource: post, state: 'draft')
create(:status, resource: post, state: 'public')
create(:status, resource: post, state: 'trash')

primes = Status.where(resource: post, resource_role: 'status').prime

primes.count       # => 1
primes.first.state # => "trash"
```

(sourced from `spec/models/poly/stack_spec.rb`'s "keeps exactly one prime per
resource and role" example)

## Append/Supersede Contract

The contract is **immutable payload, mutable linkage/index metadata** — this
is *not* a literally append-only/immutable-row stack. Prior cards are never
deleted, but their `is_prime` and `superseded_by_id` columns are mutated in
place when a new card supersedes them. This is the current, corrected wording
from `lib/poly/stack.rb`'s own module comment (a prior "append-only" claim in
this codebase was overstated and has since been corrected).

## Concurrency Boundary

`poly_stack_seize_prime`'s demote-then-insert sequence is **not** wrapped in
an explicit row lock or transaction. Two concurrent writers racing the same
`(resource, role)` can both read/demote the same prior prime and both attempt
to insert with `is_prime: true`.

It is the partial unique index — not the `before_create` callback — that
actually enforces "at most one prime per `(resource, role)`" under a race.
The index is built by `poly_prime_index` (`lib/poly/migration.rb`), named
`index_#{table}_prime` (e.g. `index_statuses_prime` in `spec/spec_helper.rb`)
— `unique: true, where: 'is_prime'` on `[type, id, role]`. The losing
writer's `INSERT` raises `ActiveRecord::RecordNotUnique` at the `INSERT`
itself, after the callback has already run.

`Poly::Stack` does not catch or retry this internally. Callers writing
concurrently to the same `(resource, role)` must be prepared to rescue
`ActiveRecord::RecordNotUnique` around the create call and retry, per the
recommended pattern in README.md's "Concurrency Boundary" section:

```ruby
begin
  post.statuses.create!(state: 'public')
rescue ActiveRecord::RecordNotUnique
  # another writer won the race for this (resource, role); re-fetch and
  # decide whether to retry, merge, or surface a conflict to the caller.
  retry_or_handle_conflict
end
```

`spec/models/poly/stack_spec.rb`'s "concurrency boundary" examples
demonstrate exactly this: that the partial unique index — not
`poly_stack_seize_prime`'s demote step — is what actually enforces "at most
one prime per `(resource, role)`" when two writers race.

## Wiring a Parent

Poly ships only `Poly::Stack` (the card-side concern) — there is no
`has_stack` macro shipped by Poly. The parent-side accessor macro is the
consumer's to write, the same pattern as Midas writing `has_coin` on
`Poly::Role`. The real, spec-verified wiring is a plain `has_many`/`has_one`
association pair, sourced from `Post` in `spec/spec_helper.rb` (no macro):

```ruby
class Post < ApplicationRecord
  has_many :statuses, -> { for_role('status').order(created_at: :desc) },
           as: :resource, class_name: 'Status'
  has_one :status, -> { for_role('status').prime },
          as: :resource, class_name: 'Status'
end
```

`for_role` comes from `Poly::Role` (inherited via `poly_stack`); composed
with the `prime` scope, that's all the parent-side wiring needs.

> [!NOTE]
> README.md's "Wiring a Parent" section also shows a fuller `has_stack`
> macro (a `Stackable` concern) that composes `where_status`/`ever_status`/
> etc. scopes on top of the same associations. That macro is **illustrative
> only** — it is not shipped by Poly and has no spec coverage. Don't treat it
> as something Poly provides.

## Working Example

Built on the real `Status`/`Post` models (`spec/spec_helper.rb`) and the
`:status` factory (`spec/factories/statuses.rb`: `resource factory:
%i[post]`, `resource_role { 'status' }`, `state { 'public' }`):

```ruby
post.statuses.create!(state: 'draft')
post.statuses.create!(state: 'public')

post.reload.status.state              # => "public"
post.reload.statuses.map(&:state)     # => ["draft", "public"] (order not guaranteed)
```

Creating a `:status` card with `state: 'draft'` then a second with `state:
'public'` on the same `post` leaves the second's `is_prime` `true` and the
first's `is_prime` `false`, with the first's `superseded_by_id` pointing at
the second's `id` — sourced from `spec/models/poly/stack_spec.rb`'s
"priming" and "supersession chain" examples. `post.status.state` (the
role-scoped `has_one`) returns `'public'`; `post.statuses.map(&:state)` (the
role-scoped `has_many`) returns both states.

## Soft-Delete (Illustrative)

> [!NOTE]
> This is an **application-level usage pattern**, not a feature `Poly::Stack`
> implements. There is no soft-delete column or behavior in
> `lib/poly/stack.rb` or the `statuses` table (`spec/spec_helper.rb`).

`Poly::Stack` can be used as the primitive behind soft-delete-as-history: a
`trash` card is a deletion, a later card is a restore, and the stack is the
audit trail. The meaning stays in your app — one-liners over your own
`has_stack`/association scopes, e.g. (from README.md's "Soft-Delete"
section):

```ruby
scope :live,    -> { without_status(:trash) }
scope :trashed, -> { where_status(:trash) }
```

## Next Steps

Continue with [Migration](./migration) for the migration helpers that keep
stack (and role/owner) schema consistent across tables.

[Home](./) · Back to [Owners](./owners)
