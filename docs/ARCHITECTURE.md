# Architecture

## Boundaries

- Root package `joanna/moonfeed`: public `parse` auto-detection entry point and explicit `parse_json_feed`, `parse_rss`, and `parse_atom` entry points.
- `src/detect`: JSON/RSS/Atom classification using the XML reader's expanded root name.
- `src/model`: shared `Feed`, `FeedItem`, `Author`, `Attachment`, and `FeedLink` types.
- `src/jsonfeed`: JSON decoding, supported-field validation, and normalization.
- `src/rss`: RSS XML event consumption, RSS-specific raw types, typed validation, and normalization.
- `src/atom`: Atom 1.0 XML event consumption, field validation, and normalization.
- `examples/basic`: executable JSON Feed example with typed error handling.
- `cli`: Node.js-hosted executable frontend for detect, inspect, and normalized JSON output; it delegates parsing to the public unified entry point.
- `fixtures/jsonfeed`, `fixtures/rss`, and `fixtures/malformed`: small inputs used by tests and review.

RSS and Atom XML parsing use MoonFeed internal package `src/xmlmini`; it is not re-exported from the root library API and is not supported as a standalone XML library. `moon.mod` has no non-core XML dependency. The project minimum is MoonBit v0.10.14; CI and development verification use the v0.10.14 toolchain series.

## CLI data flow

`File or stdin -> CLI -> parse(input) -> Detection -> Format Parser -> Normalization -> Unified Feed -> Inspect or core JSON serialization`

The CLI contains no format parser. It reads bytes/text through Node.js host APIs, calls the same library parser used by applications, and serializes its result with the MoonBit core JSON AST/stringifier.

## Data flow

`RSS/XML String -> src/xmlmini events -> RSS Node view -> RSS Channel/Item -> unified Feed`
`Atom/XML String -> src/xmlmini events -> Atom node view -> Atom normalization -> unified Feed`

`JSON String -> core/json AST -> validated fields -> unified Feed`

`src/xmlmini` is a deliberately small internal event reader for the feed formats. Its original event API preserves qualified names for RSS. A namespace-aware event API expands element and attribute names to `(namespace URI, local name)`, tracks inherited and rebound prefix scopes, handles default namespace reset, applies the implicit `xml` binding and reserved-prefix constraints, leaves unprefixed attributes outside the default namespace, and rejects duplicate expanded attribute names. It also handles XML declarations, start/end/self-closing tags, quoted attributes, text, CDATA, comments, the five basic XML entities, decimal/hex numeric entities, and mismatched or unclosed tags. It does not implement general DTD validation, external entities, XML 1.1, schemas, XPath, streaming I/O, encoding conversion, or complete XML well-formedness validation.

## Format detection and unified parser

Input is lightly classified by `src/detect` before the selected format parser runs:

Input
  ↓
Format Detection
  ├ JSON Feed candidate
  ├ RSS
  └ Atom
  ↓
Format-specific parser
  ↓
Normalizer
  ↓
Unified Feed Model

The detector skips a leading UTF-8 BOM and XML whitespace, then uses the namespace-aware reader to consume comments and the XML declaration before inspecting the root element. A leading opening brace selects a JSON Feed candidate; it does not validate JSON or the Feed schema. An unqualified `rss` root selects RSS. `feed` or `entry` selects Atom only when its expanded namespace URI is `http://www.w3.org/2005/Atom`, independent of the chosen prefix. Other roots or namespace URIs are UnknownFormat; malformed namespace bindings are MalformedPrefix.

Detection is deliberately not complete format validation and does not parse the full document. Each existing parser owns syntax and schema validation. The unified ParseError preserves a DetectError or the corresponding JSON Feed, RSS, or Atom typed parser error. BOM removal is applied before dispatch so the JSON parser also receives a clean input string. Explicit format-specific entry points remain public.
## RSS parser layer

`src/rss/parser.mbt` consumes `src/xmlmini` events and builds a small private element view. RSS core fields are matched by their full unprefixed names; prefixed extension names remain intact and are ignored by core mapping. Text and CDATA are combined; surrounding XML whitespace is trimmed; entities are decoded by the internal reader; repeated `category` children remain ordered; self-closing elements are valid empty elements.

The raw public RSS types retain channel metadata such as generator, docs, ttl, image, comments, source, guid permalink state, and enclosure attributes. The parser requires RSS root version `2.0`, one channel, channel `title` / `link` / `description`, and item `title` or `description`. An enclosure must be empty and have nonempty `url`, `type`, and unsigned decimal `length` attributes.

## RSS normalization layer

`src/rss/normalize.mbt` maps RSS raw values into the existing unified model:

- channel title and description map to `Feed.title` and `Feed.description`;
- channel link maps to `Feed.home_page_url`;
- channel categories map to `Feed.categories`;
- `lastBuildDate`, falling back to `pubDate`, maps to `Feed.updated`;
- item guid maps to `FeedItem.id`; if absent, nonempty item link is the stable fallback;
- an item with neither guid nor link returns `InvalidRequiredField` instead of receiving a random ID;
- item title and link map to `title` and `url`;
- item description is retained as both `summary` and `content_html` because RSS does not declare its markup semantics;
- author becomes an `Author` with `name`; repeated categories become `FeedItem.categories`;
- enclosure maps to one `Attachment` with url, MIME type, and byte length.

RSS `source`, comments, guid permalink metadata, generator, docs, ttl, and image are retained in the raw RSS API. Fields with no unified-model slot are not silently used to invent semantics. The RSS parser also recognizes the standard Apple Podcasts/iTunes namespace for enclosure duration in the common model; `parse_podcast_rss` returns a separate `PodcastFeed` wrapper for show and episode metadata.

## Atom parser and normalization

src/atom consumes the shared src/xmlmini event stream. It requires feed id, title, and updated, and requires entry id, title, and updated. Feed id is validated but the shared model has no feed-id field. Entry ids are copied verbatim and are never synthesized. Original date strings remain available; successfully parsed dates also carry normalized UTC instants. Invalid required updated dates return typed errors.

Feed subtitle maps to Feed.description; feed self and alternate links map to feed_url and home_page_url. Entry alternate links map to FeedItem.url; enclosure links map to attachments. An omitted rel defaults to alternate. The first alternate and first self link are used. Link type, hreflang, and title metadata outside enclosure attachments are not retained. Unknown rel values are ignored because Feed has no link-collection slot.

Atom person names and URIs map to Author.name and Author.url. Multiple authors are retained. An entry with no author inherits feed authors; an entry with its own author list uses that list. `xml:lang` is inherited by feed and entry and an empty value clears the inherited language. Contributors and person emails have no shared-model fields and are not placed in authors. Atom category term attributes populate categories; a missing term raises a path-specific error.

Text constructs default to type=text: text maps to content_text, html maps to content_html, and xhtml is reduced to readable descendant text and mapped to content_html. Other media types are not mapped to content fields yet. XML event order is retained while extracting nested XHTML so mixed text stays in order. Feed/entry rights, generator, icon, logo, entry source, feed id, and unsupported person/link details have no slots in the shared model and are discarded during normalization.

Every Atom field lookup compares the expanded name against the Atom namespace URI and the required local name. Default namespace and arbitrary prefix representations therefore have the same result, while foreign extension elements with colliding local names are ignored. The reader resolves namespace bindings but remains a feed-focused XML subset reader, not a general XML namespace or validation library. The current Atom implementation is not fully RFC 4287 conformant: it accepts Feed Documents only, drops unsupported metadata and extensions, does not resolve `xml:base` relative IRIs, and validates only the common subset of constructs and cardinality rules. See [ATOM_RFC4287_COMPLIANCE.md](ATOM_RFC4287_COMPLIANCE.md) for the audited status and follow-up work.
## Dates and errors

Parser output follows the path Format parser -> raw date -> src/datetime -> normalized UTC representation -> unified Feed model. The existing String? date fields remain available as extracted by their format parsers. Feed.updated_at, FeedItem.published_at, and FeedItem.updated_at hold an optional DateTime { raw, unix_seconds }; Unix seconds use Int64, giving a comparable and serializable UTC instant. The MoonBit v0.10.14 core library has no calendar parser suitable for these feed formats, so src/datetime implements only the constrained feed-date subset.

RFC 3339 requires Z or a numeric ±HH:MM offset. RSS accepts an optional abbreviated weekday, English three-letter month names, GMT, UTC, or numeric ±HHMM / ±HH:MM offsets. Weekdays are syntax only and are not verified against the calendar date. Ambiguous abbreviations such as EST, PST, and CST return UnsupportedTimezone; no DST database or abbreviation guessing is used.

Calendar fields, Gregorian leap years, clock fields, and offsets are validated. Supported years are 0001–9999. Leap seconds are rejected. RFC 3339 fractional digits must be nonempty and are truncated to whole seconds; the Unix value denotes the beginning of that second.

Invalid optional JSON Feed/RSS dates and Atom published values do not reject the Feed: raw remains intact and the parsed field is None. Atom feed/entry updated values are required; an invalid value returns InvalidDateTime with its field path and typed DateTimeError. A missing required Atom updated retains the existing missing-field error.

Atom also raises InvalidXml, InvalidAtomRoot, and InvalidRequiredField errors with paths such as feed.entry[2].link[1].href or feed.entry[1].category[0].term.

RSS raises typed errors with paths such as `channel.item[2].enclosure.url`. Invalid XML, unsupported versions, missing channel/title/link/description, invalid enclosure attributes, and missing stable item identity are distinguished. The operation is atomic and does not return partial feeds.

## Verification and growth

The current suite has 88 behavior tests. It includes Atom namespace equivalence, expansion, scope rebinding/reset, reserved bindings, duplicate expanded attributes, and foreign-element collision cases, alongside the existing JSON Feed/RSS/date/CLI regression suite. CI installs the official latest channel and logs its MoonBit/moonc versions; local validation uses v0.10.14, and the actual CI version is confirmed from each run.

Atom consumes the same internal XML event reader and normalizes into the shared model. Podcast RSS metadata is exposed through a separate wrapper so existing Feed and FeedItem layouts stay stable. Datetime normalization preserves source strings and stores normalized UTC instants in adjacent parsed fields.
