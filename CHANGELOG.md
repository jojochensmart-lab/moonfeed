# Changelog

## Unreleased

- Resolve Atom element and attribute names by namespace URI and local name in parsing and format detection; arbitrary prefixes are supported and foreign elements with colliding names are ignored.
- Preserve the existing XML event API for RSS while adding namespace scope, reserved binding, unqualified attribute, and duplicate expanded-attribute handling.
- Add Atom namespace equivalence and XML namespace edge-case tests, and document the remaining RFC 4287 compatibility gaps.

## 0.1.0 — 2026-10-03

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
- Publish `joanna/moonfeed@0.1.0` to Mooncakes.

- Add CLI `detect`, `inspect`, and `normalize` commands.
- Add deterministic normalized Feed JSON serialization with the core JSON serializer.

## 0.1.1 — 2026-10-20

- Parse Apple Podcasts/iTunes RSS show and episode metadata through a dedicated API; normalize episode duration into enclosure attachments.
- Add Podcast metadata coverage for show and episode fields, validation errors, and CLI normalized output.
- Document Podcast support, API usage, supported fields, and current XML/extension limitations.

## 0.1.2 — 2026-10-20

- Export `detect_format(...)` from the root package so registry users can call the documented format detection API.
