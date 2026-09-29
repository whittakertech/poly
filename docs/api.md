# API Reference

Poly's full API reference is generated from the source with YARD and published
through Codex.

- [`Poly`](./api/Poly/)
- [`Poly::Joins`](./api/Poly/Joins/)
- [`Poly::Role`](./api/Poly/Role/)
- [`Poly::Owners`](./api/Poly/Owners/)
- [`Poly::Stack`](./api/Poly/Stack/)
- [`Poly::Migration`](./api/Poly/Migration/)

Regenerate the API pages locally with:

```bash
bundle exec rake docs:api
ruby scripts/normalize_yard_markdown.rb docs/api
```
