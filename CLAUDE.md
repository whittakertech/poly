# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Poly is a Ruby gem providing type-safe joins and role identity utilities for polymorphic `belongs_to` associations in Rails. It targets Ruby >= 3.2 and ActiveRecord/ActiveSupport >= 7.1.

## Commands

```bash
bundle install              # Install dependencies
bundle exec rspec           # Run all tests
bundle exec rspec spec/models/poly/joins_spec.rb   # Run a single test file
bundle exec rspec spec/models/poly/joins_spec.rb:15 # Run a single example by line
bundle exec rubocop         # Lint
bundle exec rubocop -a      # Auto-fix lint issues
COVERAGE=true bundle exec rspec  # Run tests with coverage report
```

The default Rake task runs RSpec: `bundle exec rake`

## Architecture

The gem has three core modules, all implemented as `ActiveSupport::Concern` mixins:

- **`Poly::Joins`** (`lib/poly/joins.rb`) — Dynamically generates type-safe INNER JOIN methods for polymorphic `belongs_to` associations. Calling `define_polymorphic_joins!` creates methods like `joins_commentable(ClassName)` that validate the target class has the reverse `has_many`/`has_one` association before building the join SQL.

- **`Poly::Role`** (`lib/poly/role.rb`) — Adds a validated role column to polymorphic associations via `poly_role(assoc_name, max_length: 64, immutable: false)`. Normalizes roles (strip + downcase) before validation and in `for_role` queries. Validates format (`/\A[a-z0-9_]+\z/`). `immutable: true` adds an `on: :update` validation preventing role changes after create.

- **`Poly::Owners`** (`lib/poly/owners.rb`) — Stamps `owner_type`/`owner_id` columns (or custom equivalents) before validation via `poly_owner(assoc_name, owner:, type_column:, id_column:, allow_nil: true, immutable: false)`. Validates that the named association is a polymorphic `belongs_to`. Owner must resolve to a persisted `ActiveRecord::Base`. `allow_nil: false` raises if owner is nil. `immutable: true` prevents ownership changes after create.

Entry point is `lib/poly.rb` which requires all three modules.

## Testing

Tests use RSpec with an in-memory SQLite database. Test models (Comment, Post, User, Tagging) and their schema are defined in `spec/spec_helper.rb`. Factories live in `spec/factories/`.

## Code Conventions

- All files must have `# frozen_string_literal: true`
- RuboCop enforces compact `Style::ClassAndModuleChildren` (e.g., `class Poly::Joins` not nested modules)
- `Style/Documentation` is disabled — no doc comments required
- `lib/poly/joins.rb` is excluded from Metrics/AbcSize, MethodLength, and BlockLength cops
