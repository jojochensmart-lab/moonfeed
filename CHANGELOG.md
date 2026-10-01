# Changelog

## 0.1.0 — Unreleased

- Introduce unified Feed, FeedItem, Author, Attachment, and FeedLink types.
- Parse the initial supported JSON Feed 1.1 field set into the unified model.
- Preserve text/HTML and source dates; normalize tags and author/language inheritance.
- Report typed errors with field paths; reject missing required fields, invalid
  supported types, unsupported versions, empty IDs, and duplicate IDs.
- Add 15 behavioral tests, shared fixtures, a runnable example, and architecture notes.
- RSS, Atom, attachments, datetime parsing, CLI and registry publication remain planned.
