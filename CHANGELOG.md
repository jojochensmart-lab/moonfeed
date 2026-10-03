# Changelog

## 0.1.0 — Unreleased

- Introduce unified Feed, FeedItem, Author, Attachment, and FeedLink types.
- Parse JSON Feed 1.1 and normalize its initial supported field set.
- Add typed JSON errors, fixtures, runnable example, and initial architecture notes.
- Adopt MoonBit >= v0.10.14 and the internal src/xmlmini reader for XML parsing.
- Remove MoonBit deprecated syntax warnings from the project code.
- Add RSS 2.0 parsing and normalization for channel/item core fields, categories,
  authors, stable guid/link identity fallback, dates, and enclosures.
- Add RSS technical-blog and Podcast-like fixtures plus XML edge-case tests.
- Add Atom 1.0 parsing and normalization for feeds, entries, links, authors, categories, text constructs, and enclosures; retain date strings unchanged.
- Add Atom fixtures for minimal, full, prefixed, enclosure, multiple-entry, release, and technical-blog shapes, plus typed error tests.
- Add lightweight JSON Feed/RSS/Atom format detection and a unified parse entry point that preserves typed parser errors.
- Add typed RFC 3339 and RSS date parsing, timezone offset normalization, and unified UTC Unix-second values while preserving source dates.
- Integrate optional and required parsed dates into Feed / FeedItem; malformed optional dates retain raw values, invalid Atom updated dates return typed errors.
- Registry publication remains planned.

## Unreleased

- Add CLI `detect`, `inspect`, and `normalize` commands.
- Add deterministic normalized Feed JSON serialization with the core JSON serializer.
