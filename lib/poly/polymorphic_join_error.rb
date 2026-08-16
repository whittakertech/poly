# frozen_string_literal: true

class Poly::PolymorphicJoinError < StandardError; end

# Deprecated: use Poly::PolymorphicJoinError. Kept as an alias so existing
# `rescue PolymorphicJoinError` / `is_a?(PolymorphicJoinError)` callers keep
# working across the 1.2.0 rename.
PolymorphicJoinError = Poly::PolymorphicJoinError
