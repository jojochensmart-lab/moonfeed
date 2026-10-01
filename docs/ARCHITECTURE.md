# Architecture

## Boundaries

- Root package `joanna/moonfeed`: public `parse_json_feed`, `parse_rss`, and `parse_atom` entry points.
- `src/model`: shared `Feed`, `FeedItem`, `Author`, `Attachment`, and `FeedLink` types.
- `src/jsonfeed`: JSON decoding, supported-field validation, and normalization.
- `src/rss`: RSS XML event consumption, RSS-specific raw types, typed validation, and normalization.
- `src/atom`: Atom 1.0 XML event consumption, field validation, and normalization.
- `examples/basic`: executable JSON Feed example with typed error handling.
- `fixtures/jsonfeed`, `fixtures/rss`, and `fixtures/malformed`: small inputs used by tests and review.

RSS XML parsing uses MoonFeed internal package `src/xmlmini`; `moon.mod` has no non-core XML dependency. The project minimum is MoonBit v0.10.14; CI and development verification use the v0.10.14 toolchain series.

## Data flow

`RSS/XML String -> src/xmlmini events -> RSS Node view -> RSS Channel/Item -> unified Feed`
`Atom/XML String -> src/xmlmini events -> Atom node view -> Atom normalization -> unified Feed`

`JSON String -> core/json AST -> validated fields -> unified Feed`

`src/xmlmini` is a deliberately small internal event reader for the feed formats. It handles XML declarations, start/end/self-closing tags, quoted attributes, text, CDATA, comments, the five basic XML entities, decimal/hex numeric entities, and mismatched or unclosed tags. It keeps qualified names such as `content:encoded` intact and does not resolve namespace semantics. It does not implement DTD validation, external entities, XML 1.1, schemas, XPath, streaming I/O, or encoding conversion.

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

RSS `source`, comments, guid permalink metadata, generator, docs, ttl, and image are retained in the raw RSS API. Fields with no unified-model slot are not silently used to invent semantics.

## Atom parser and normalization

src/atom consumes the shared src/xmlmini event stream. It requires feed id, title, and updated, and requires entry id, title, and updated. Feed id is validated but the shared model has no feed-id field. Entry ids are copied verbatim and are never synthesized. Date strings remain unchanged; no RFC 3339 validation or timezone conversion occurs.

Feed subtitle maps to Feed.description; feed self and alternate links map to feed_url and home_page_url. Entry alternate links map to FeedItem.url; enclosure links map to attachments. An omitted rel defaults to alternate. The first alternate and first self link are used. Link type, hreflang, and title metadata outside enclosure attachments are not retained. Unknown rel values are ignored because Feed has no link-collection slot.

Atom person names and URIs map to Author.name and Author.url. Multiple authors are retained. An entry with no author inherits feed authors; an entry with its own author list uses that list. Contributors and person emails have no shared-model fields and are not placed in authors. Atom category term attributes populate categories; a missing term raises a path-specific error.

Text constructs default to type=text: text maps to content_text, html maps to content_html, and xhtml is reduced to readable descendant text and mapped to content_html. Other media types are not mapped to content fields yet. XML event order is retained while extracting nested XHTML so mixed text stays in order. Feed/entry rights, generator, icon, logo, entry source, feed id, and unsupported person/link details have no slots in the shared model and are discarded during normalization.

Namespace matching recognizes unprefixed names and the literal atom: prefix by local name. It does not validate namespace URIs or resolve arbitrary prefix bindings. Other prefixed elements such as ext:title are ignored. This covers required common shapes while keeping xmlmini feed-focused rather than introducing a complete namespace engine.
## Dates and errors

RSS and JSON Feed dates remain `String?` values. The parser preserves original RFC 822/RFC 1123 or RFC 3339 text; date parsing and normalization are planned for a later phase.

Atom also raises InvalidXml, InvalidAtomRoot, and InvalidRequiredField errors with paths such as feed.entry[2].link[1].href or feed.entry[1].category[0].term.

RSS raises typed errors with paths such as `channel.item[2].enclosure.url`. Invalid XML, unsupported versions, missing channel/title/link/description, invalid enclosure attributes, and missing stable item identity are distinguished. The operation is atomic and does not return partial feeds.

## Verification and growth

The current suite has 44 behavior tests: 15 JSON Feed, 12 RSS, 5 xmlmini, and 12 Atom tests. CI uses the official `latest` installer channel, prints the installed MoonBit version, and runs `moon check`, `moon test`, `moon build`, and the example. Local validation uses MoonBit v0.10.14.

Atom consumes the same internal XML event reader and normalizes into the shared model. A future datetime layer must make timezone handling and invalid-date policy explicit before replacing source strings.

