# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Poly is a Ruby gem providing type-safe joins and labeled identity utilities for polymorphic `belongs_to` associations in Rails. It targets Ruby >= 3.4 and ActiveRecord/ActiveSupport >= 7.1.

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

The gem has two core modules, both implemented as `ActiveSupport::Concern` mixins:

- **`Poly::Joins`** (`lib/poly/joins.rb`) — Dynamically generates type-safe INNER JOIN methods for polymorphic `belongs_to` associations. Calling `define_polymorphic_joins!` creates methods like `joins_commentable(ClassName)` that validate the target class has the reverse `has_many`/`has_one` association before building the join SQL.

- **`Poly::Label`** (`lib/poly/label.rb`) — Adds a validated label column to polymorphic associations via `labeled_poly(assoc_name)`. Normalizes labels (strip + downcase), validates format (`/\A[a-z0-9_]+\z/`), and provides a `for_label` scope.

Entry point is `lib/poly.rb` which requires both modules.

## Testing

Tests use RSpec with an in-memory SQLite database. Test models (Comment, Post, User, Tagging) and their schema are defined in `spec/spec_helper.rb`. Factories live in `spec/factories/`.

## Code Conventions

- All files must have `# frozen_string_literal: true`
- RuboCop enforces compact `Style::ClassAndModuleChildren` (e.g., `class Poly::Joins` not nested modules)
- `Style/Documentation` is disabled — no doc comments required
- `lib/poly/joins.rb` is excluded from Metrics/AbcSize, MethodLength, and BlockLength cops
