# Privacy

Wheel's MVP is designed to work without:

- user accounts
- cloud sync
- remote history storage
- page-body collection
- source-code collection
- content indexing
- an AI service

The product needs enough local metadata to identify and restore a useful work context, but nothing more.

## Principles

1. **Local by default** — history stays on the Mac.
2. **Minimal fields** — store identity, not content.
3. **Explicit exclusions** — users can exclude applications.
4. **Bounded retention** — history should not grow forever.
5. **Clear means clear** — clearing history must leave a valid empty state.
6. **Redacted diagnostics** — debug/support logs must not become a second history database.

The exact native persistence schema will be documented before persistence ships.
