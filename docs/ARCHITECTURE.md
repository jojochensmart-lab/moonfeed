# Architecture

## Boundaries

- Root package `joanna/moonfeed`: existing normalization APIs plus `parse_atom_document` / `parse_atom_document_with_base` and re-exported Atom document types.
- `src/detect`: JSON/RSS/Atom classification using the XML reader's expanded root name.
- `src/model`: shared `Feed`, `FeedItem`, `Author`, `Attachment`, and `FeedLink` types.
- `src/jsonfeed`: JSON decoding, supported-field validation, and normalization.
- `src/rss`: RSS XML event consumption, RSS-specific raw types, typed validation, and normalization.
- `src/atom`: Atom 1.0 XML event consumption, field validation, and normalization.
- `examples/basic`: executable JSON Feed example with typed error handling.
- `cli`: Node.js-hosted executable frontend for detect, inspect, and normalized JSON output; it delegates parsing to the public unified entry point.
- `fixtures/jsonfeed`, `fixtures/rss`, and `fixtures/malformed`: small inputs used by tests and review.

RSS and Atom XML parsing use MoonFeed internal package `src/xmlmini`; it is not re-exported as a standalone XML library. `moon.mod` has no non-core XML dependency. The project minimum and local verification toolchain are MoonBit v0.10.14. CI uses the official latest channel and records the actual installed versions.

## CLI data flow

`File or stdin -> CLI -> parse(input) -> Detection -> Format Parser -> Normalization -> Unified Feed -> Inspect or core JSON serialization`

The CLI contains no format parser. It reads bytes/text through Node.js host APIs, calls the same library parser used by applications, and serializes its result with the MoonBit core JSON AST/stringifier.

## Data flow

`RSS/XML String -> src/xmlmini events -> RSS Node view -> RSS Channel/Item -> unified Feed`
`Atom/XML String -> src/xmlmini events -> Atom node view -> Atom normalization -> unified Feed`

`Atom/XML String -> namespace/base/language-scoped node view -> document validation -> AtomDocument(FeedDocument | EntryDocument)`

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

## Atom document API and semantic retention

The new document API returns distinct Feed and standalone Entry variants. It validates the implemented RFC 4287 requirements without constructing a synthetic Feed for an Entry. The root module exports AtomDocument, AtomFeed, AtomEntry, AtomMetadata, AtomPerson, AtomLink, AtomCategory, AtomText, AtomContent, AtomDate, IriReference and expanded markup types.

Each Atom node carries inherited xml:lang and xml:base. Base resolution parses scheme/authority/path/query/fragment and implements RFC 3986 path merging and dot-segment removal. Empty and fragment XML bases are resolved normally; XML Base LEIRI spaces remain unescaped in returned bases. Reference values carry raw/resolved/is_absolute; a caller may supply a retrieval URI. IDs are absolute and preserved character-for-character rather than base-resolved or normalized.

Feed/entry singletons, required values, structural placement, author conditions, alternate-link tuples, content/link presence and mandatory summaries are checked. Source uses optional feed metadata rules. Effective authors follow entry, then source, then feed; rights inherit from the containing feed. Source, contributors/email, all links/categories, generator, rights, icon/logo and expanded-name extension trees remain accessible. Metadata/source IDs are retained.

Text and HTML reject child elements. XHTML requires a single div in the XHTML namespace and preserves mixed content; the wrapper is excluded from AtomContent.markup while retained in raw. XML media types retain expanded markup, text media types retain text, binary types validate/decode Base64, and external src content must be empty. Missing external type remains unknown. Link length_raw preserves arbitrary-size decimal integers even when UInt64 conversion is unavailable.

AtomDate applies uppercase T/Z and RFC 3339 calendar rules, preserves fractional digits and -00:00, supports Gregorian year 0000 and recorded positive leap seconds. Leap transitions use public-domain IANA/IERS data through 2017-01-01; future announcements require maintenance. POSIX seconds cannot distinguish a leap second from the next second, so raw/leap_second/fractional_digits remain explicit.

The retained XML tree is semantic, not a byte-preserving serializer: comments, processing instructions and original namespace prefixes are not retained. XML declarations (syntax/order/strict placement), general PI skipping, XML Name, physical line endings and literal attribute whitespace are now processed. Character references are decoded after physical normalization. DTD/internal declared entities and DTD attribute defaults/types remain unsupported. Namespace URI-reference checks now validate scheme and authority structure, userinfo/port syntax, relative path colons, brackets and escapes. Full IP-literal validation and every URI path production remain incomplete; some historical email/MIME productions also remain incomplete. The exact scope is audited in [ATOM_RFC4287_COMPLIANCE.md](ATOM_RFC4287_COMPLIANCE.md).

Strict document validation recursively checks explicit xml:lang using RFC3066 syntax without a registry lookup. hreflang uses the same grammar without the XML empty-reset exception. media.mbt parses MIME tokens/comments/FWS/quoted parameters and compares parameter multisets while retaining raw values; charset is case-insensitive, unknown parameter values are not folded. Both content dispatch and summary requirements use parsed MIME essence. ip_literal.mbt validates IPv6/IPvFuture and Unicode component ranges. These are implementation checks, not third-party conformance certification.

See [API_COMPATIBILITY](API_COMPATIBILITY.md) for strict versus legacy behavior and the unpublished release strategy. Only internal reader constructors gain an optional strict_declaration argument; root package signatures and document models are unchanged.

## Legacy Atom normalization and migration

src/atom consumes the shared src/xmlmini event stream. It requires feed id, title, and updated, and requires entry id, title, and updated. Feed id is validated but the shared model has no feed-id field. Entry ids are copied verbatim and are never synthesized. Original date strings remain available; successfully parsed dates also carry normalized UTC instants. Invalid required updated dates return typed errors.

Feed subtitle maps to Feed.description; feed self and alternate links map to feed_url and home_page_url. Entry alternate links map to FeedItem.url; enclosure links map to attachments. An omitted rel defaults to alternate. The first alternate and first self link are used. Link type, hreflang, and title metadata outside enclosure attachments are not retained. Unknown rel values are ignored because Feed has no link-collection slot.

Atom person names and URIs map to Author.name and Author.url. Multiple authors are retained. An entry with no author inherits feed authors; an entry with its own author list uses that list. `xml:lang` is inherited by feed and entry and an empty value clears the inherited language. Contributors and person emails have no shared-model fields and are not placed in authors. Atom category term attributes populate categories; a missing term raises a path-specific error.

Text constructs default to type=text: text maps to content_text, html maps to content_html, and xhtml is reduced to readable descendant text and mapped to content_html. Other media types are not mapped to content fields yet. XML event order is retained while extracting nested XHTML so mixed text stays in order. Feed/entry rights, generator, icon, logo, entry source, feed id, and unsupported person/link details have no slots in the shared model and are discarded during normalization.

Every field lookup compares the Atom namespace URI and local name. The legacy normalization APIs retain their Feed return type and historical permissive common-field behavior, including legacy inputs lacking constraints now checked by the document API. They still accept Feed Documents only and discard values without unified-model fields. Their links now use the shared base resolver. Callers requiring standalone Entry semantics, validation or retained Atom metadata should migrate to the document API; a full-conformance claim does not apply to either API until the audited gaps are closed.
## Dates and errors

Parser output follows the path Format parser -> raw date -> src/datetime -> normalized UTC representation -> unified Feed model. The existing String? date fields remain available as extracted by their format parsers. Feed.updated_at, FeedItem.published_at, and FeedItem.updated_at hold an optional DateTime { raw, unix_seconds }; Unix seconds use Int64, giving a comparable and serializable UTC instant. The MoonBit v0.10.14 core library has no calendar parser suitable for these feed formats, so src/datetime implements only the constrained feed-date subset.

RFC 3339 requires Z or a numeric ±HH:MM offset. RSS accepts an optional abbreviated weekday, English three-letter month names, GMT, UTC, or numeric ±HHMM / ±HH:MM offsets. Weekdays are syntax only and are not verified against the calendar date. Ambiguous abbreviations such as EST, PST, and CST return UnsupportedTimezone; no DST database or abbreviation guessing is used.

Calendar fields, Gregorian leap years, clock fields, and offsets are validated. Supported years are 0001–9999. Leap seconds are rejected. RFC 3339 fractional digits must be nonempty and are truncated to whole seconds; the Unix value denotes the beginning of that second.

Invalid optional JSON Feed/RSS dates and Atom published values do not reject the Feed: raw remains intact and the parsed field is None. Atom feed/entry updated values are required; an invalid value returns InvalidDateTime with its field path and typed DateTimeError. A missing required Atom updated retains the existing missing-field error.

Atom also raises InvalidXml, InvalidAtomRoot, and InvalidRequiredField errors with paths such as feed.entry[2].link[1].href or feed.entry[1].category[0].term.

RSS raises typed errors with paths such as `channel.item[2].enclosure.url`. Invalid XML, unsupported versions, missing channel/title/link/description, invalid enclosure attributes, and missing stable item identity are distinguished. The operation is atomic and does not return partial feeds.

## Verification and growth

The current suite has 138 behavior tests: the 117 baseline tests are unchanged and 21 specification-derived cases are maintained separately in atom_conformance_test.mbt with fixtures/atom/conformance. CI runs both examples/basic and examples/atom in addition to check/test/build and existing CLI smoke tests. It installs the official latest channel and logs versions; local validation uses v0.10.14, while actual CI versions must be read from each run.

Atom consumes the same internal XML event reader and normalizes into the shared model. Podcast RSS metadata is exposed through a separate wrapper so existing Feed and FeedItem layouts stay stable. Datetime normalization preserves source strings and stores normalized UTC instants in adjacent parsed fields.
