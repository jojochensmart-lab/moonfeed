# Changelog

## Unreleased

- Add bounded internal DTD support for text-only general entities, `ATTLIST` default attributes, and CDATA/tokenized attribute normalization; reject recursive, external, markup, and over-budget entity expansions with XML errors.
- Apply RFC 2046 case-insensitive parameter-value comparison for `message/external-body` access-type, permission, and mode; retain RFC 2045 case-sensitive defaults for other values.
- Add Atom typed-error path assertions and MIME quoted-pair, DTD namespace-default, entity expansion and rejection tests; the suite now has 147 tests.
- Share RFC 3986 IPv6/IPvFuture literal validation between namespace URI references and Atom IRI parsing; add valid/invalid authority vectors.
- Remove the arbitrary 32-level email-comment nesting cap and cover 64 nested comments in the Atom conformance tests.
- Validate RFC 3987 IRI characters by component, cover Unicode/private-use boundaries, and preserve extended XML Base characters during RFC 3986 resolution.
- Add RFC 2822 obsolete local/domain and folded-address conformance vectors.
- Record the IERS leap-second review and maintenance process; test rejection of the unannounced 2026-12-31 candidate date.
- Record the remaining XML 1.0 DTD and MIME parameter boundaries; do not claim full RFC 4287 conformance.

## 0.2.0 — 2026-10-22

- Validate Atom namespace URI-reference scheme and authority structure, userinfo/port syntax, bracket placement and escape boundaries; keep exact URI spelling and relative namespace support. Add targeted positive/negative vectors (138 tests total).
- Add `.moonignore` so the local untracked application form, including contact details, is excluded from Mooncakes archives.
- Publish additive Atom document APIs as 0.2.0 after CI and clean registry-install verification.

- Validate RFC3066 language-tag syntax in strict Atom document APIs, preserving inheritance, overrides, empty XML reset and legacy API behavior.
- Normalize physical XML line endings and literal attribute whitespace separately from character references; validate declaration syntax/order/strict placement and XML names; skip general processing instructions.
- Validate IPv6/IPvFuture and RFC3987 Unicode/private-use ranges; reject malformed namespace-reference characters without normalizing namespace identity.
- Parse MIME comments/folding/quoted parameters, compare alternate link types/languages without dropping meaningful parameters, and fix summary classification for commented text MIME types; diagnose malformed email folding.
- Third-round baseline: add 20 independent conformance tests (137 total), an API migration policy, nine-row gap audit and October resubmission materials. No version change or Mooncakes publication at that stage.

- Add Atom Feed/Entry document APIs with distinct public result types and retained source, people, links, categories, rights, generator, content and expanded-name extension metadata. Existing normalization signatures remain unchanged.
- Add XML Base scope and RFC 3986 reference resolution, retaining original and resolved references and a caller-supplied retrieval base.
- Validate document cardinality, author conditions, content/link/summary rules and Atom-specific date syntax; retain precision, year 0000, recorded leap seconds and unknown-local-offset markers.
- Preserve XHTML/XML content and decode Base64 content; cover RFC examples, URI resolution vectors and semantic errors with 29 new tests (117 total).
- Add an executable Atom document equivalence example to CI and update the compliance matrix with remaining XML/IRI/language/email/MIME gaps. These changes are not yet published to Mooncakes.

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
