---
description: Reference for Poly::Joins, the type-safe INNER JOIN generator for polymorphic belongs_to associations, and the Poly::PolymorphicJoinError it raises.
---

# Joins

## The mechanism

`Poly::Joins` is an `ActiveSupport::Concern`. Including it into a model runs
its `included do ... end` block:

```ruby
module Poly::Joins
  extend ActiveSupport::Concern

  included do
    define_polymorphic_joins!
  end

  # ...
end
```

`define_polymorphic_joins!` walks the includer's `belongs_to` associations
and, for each one declared `polymorphic: true`, defines a class method named
`:"joins_#{assoc_name}"` — for example, a model with
`belongs_to :commentable, polymorphic: true` gets `joins_commentable`. If a
method of that name is already defined (e.g. from a previous `include`), it's
skipped rather than redefined, so re-including `Poly::Joins` on the same
model is a no-op.

## The generated method

The generated `joins_<assoc>(klass)` method takes the **target** AR class
(not an instance) — for example, `Comment.joins_commentable(Post)`, not
`Comment.joins_commentable(some_post)`. It resolves `klass.base_class`, then
returns an `ActiveRecord::Relation` with an `INNER JOIN` added on:

```
source[:"#{assoc}_id"].eq(target[:id]).and(source[:"#{assoc}_type"].eq(base_klass.name))
```

Because it returns an `ActiveRecord::Relation`, the result is chainable with
further scopes like `.where` — see the worked example below.

## The required reverse association

The class passed to `joins_<assoc>` must declare a reverse `has_many` or
`has_one ..., as: :<assoc>` association back to the includer. This is
checked via the private `join_allowed?` class method before the join is
built. If the reverse association isn't declared, `joins_<assoc>` raises
`Poly::PolymorphicJoinError` instead of silently building a join against a
class that doesn't actually participate in the polymorphic relationship.

## Poly::PolymorphicJoinError

`Poly::PolymorphicJoinError` is a plain `StandardError` subclass with no
methods of its own:

```ruby
class Poly::PolymorphicJoinError < StandardError; end
```

It's raised from two places inside a generated `joins_<assoc>` method:

1. **The argument isn't an ActiveRecord model** (`klass <= ActiveRecord::Base`
   is false):

   ```
   Expected an ActiveRecord model
   ```

2. **The argument's class doesn't declare the required reverse association**:

   ```
   Polymorphic join requires #{base_klass} to declare: has_many :#{name.underscore.pluralize}, as: :#{assoc_name}
   ```

   For example, calling `Comment.joins_commentable(SomeClass)` where
   `SomeClass` has no `has_many :comments, as: :commentable` raises:

   ```
   Polymorphic join requires SomeClass to declare: has_many :comments, as: :commentable
   ```

**To fix it:** add the stated `has_many` (or `has_one`) `..., as: :<assoc>`
association on the target class.

A deprecated top-level `PolymorphicJoinError` constant still works as an
alias to `Poly::PolymorphicJoinError`, so existing `rescue PolymorphicJoinError`
/ `is_a?(PolymorphicJoinError)` callers keep working across the 1.2.0 rename
— but new code and docs should reference `Poly::PolymorphicJoinError`
directly.

## A worked example: Comment, Post, and User

This example uses a single polymorphic association, `Comment#commentable`,
that can point at either a `Post` or a `User`:

```ruby
class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class User < ApplicationRecord
  has_many :comments, as: :commentable
end

class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true

  include Poly::Joins
end
```

Including `Poly::Joins` on `Comment` generates `Comment.joins_commentable`,
usable against either reverse-associated class:

```ruby
Comment.joins_commentable(Post) # => an ActiveRecord::Relation
Comment.joins_commentable(User) # => an ActiveRecord::Relation
```

The generated SQL for the `Post` join includes the join itself and a
`commentable_type` predicate:

```ruby
Comment.joins_commentable(Post).to_sql
# includes: INNER JOIN "posts"
# includes: "comments"."commentable_id" = "posts"."id"
# includes: "comments"."commentable_type" = 'Post'
```

Being an `ActiveRecord::Relation`, it's chainable with further scopes:

```ruby
Comment.joins_commentable(Post).where(posts: { title: "Hello" })
```

### The error case

If the class passed to `joins_commentable` doesn't declare the reverse
association, `Poly::PolymorphicJoinError` is raised with the message pattern
described above. For example, a class without `has_many :comments, as:
:commentable`:

```ruby
class Unrelated < ApplicationRecord
  self.table_name = "posts"
end

Comment.joins_commentable(Unrelated)
# raises Poly::PolymorphicJoinError:
#   "Polymorphic join requires Unrelated to declare: has_many :comments, as: :commentable"
```

## Next Steps

Continue with [Role](./role) to give a polymorphic association semantic
meaning via a normalized `role` column.

[Home](./)
