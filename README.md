# Poly

Type-safe joins and labeled identity for polymorphic `belongs_to` associations in Rails.

## Installation

Add to your Gemfile:

```ruby
gem 'poly'
```

Then run `bundle install`.

## Requirements

- Ruby >= 3.2
- ActiveRecord >= 7.1

## Usage

### Poly::Joins

Generates type-safe `INNER JOIN` methods for polymorphic associations. Include the module in a model that has a polymorphic `belongs_to`, and it will define a `joins_<association>` class method for each one.

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true

  include Poly::Joins
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class User < ApplicationRecord
  has_many :comments, as: :commentable
end
```

Now you can join through the polymorphic association by passing the target class:

```ruby
# Join comments to the posts table
Comment.joins_commentable(Post)
# => SELECT "comments".* FROM "comments"
#    INNER JOIN "posts"
#    ON "comments"."commentable_id" = "posts"."id"
#    AND "comments"."commentable_type" = 'Post'

# Chainable with other scopes
Comment.joins_commentable(Post).where(posts: { title: 'Hello' })

# Join to a different target type
Comment.joins_commentable(User).where(users: { name: 'Lee' })
```

**Safety:** The target class must declare the reverse association (`has_many` or `has_one` with `as: :commentable`). If it doesn't, a `PolymorphicJoinError` is raised:

```ruby
Comment.joins_commentable(Unrelated)
# => PolymorphicJoinError: Unrelated must declare has_one/has_many as: :commentable
```

### Poly::Label

Adds a validated label column to a polymorphic association. This is useful when a single polymorphic relationship needs to distinguish between different roles or categories.

Your table needs a `<association>_label` string column:

```ruby
create_table :taggings do |t|
  t.references :taggable, polymorphic: true, null: false
  t.string :taggable_label, null: false
  t.timestamps
end
```

Then include the module and declare the labeled association:

```ruby
class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  include Poly::Label

  labeled_poly :taggable
  # optionally: labeled_poly :taggable, max_length: 128
end
```

This gives you:

- **Normalization** — labels are stripped and downcased before validation
- **Validation** — labels must match `/\A[a-z0-9_]+\z/` and be at most 64 characters (configurable via `max_length:`)
- **Scope** — `for_label` to query by label

```ruby
tagging = Tagging.new(taggable: post, taggable_label: '  Primary  ')
tagging.valid?
tagging.taggable_label # => "primary"

Tagging.for_label('primary')
# => SELECT * FROM "taggings" WHERE "taggable_label" = 'primary'
```

## Development

```bash
bundle install              # Install dependencies
bundle exec rspec           # Run tests
bundle exec rubocop         # Lint
COVERAGE=true bundle exec rspec  # Run tests with coverage report
```

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).
