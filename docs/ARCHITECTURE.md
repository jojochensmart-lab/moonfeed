# Architecture

## Boundaries

- Root package `joanna/moonfeed`: public `parse_json_feed` and `parse_rss` entry points.
- `src/model`: shared `Feed`, `FeedItem`, `Author`, `Attachment`, and `FeedLink` types.
- `src/jsonfeed`: JSON decoding, supported-field validation, and normalization.
- `src/rss`: RSS XML event consumption, RSS-specific raw types, typed validation, and normalization.
- `examples/basic`: executable JSON Feed example with typed error handling.
- `fixtures/jsonfeed`, `fixtures/rss`, and `fixtures/malformed`: small inputs used by tests and review.

RSS / Atom parsing is built on `Milky2018/xml@0.5.0`, an Apache-2.0 licensed XML library. The project minimum is MoonBit v0.10.14; CI and development verification use the v0.10.14 toolchain series.

## Data flow

`RSS/XML String -> Milky2018/xml events -> RSS Node view -> RSS Channel/Item -> unified Feed`

`JSON String -> core/json AST -> validated fields -> unified Feed`

The XML dependency owns tokenization, entity expansion, CDATA, attributes, namespace resolution, and well-formedness. MoonFeed only walks events to apply RSS semantics. It does not implement a second XML tokenizer.

## RSS parser layer

`src/rss/parser.mbt` consumes `NamespaceReader` events and builds a small private element view. Namespaced children are ignored for RSS core mapping, while unnamespaced RSS elements are matched by local name. Text and CDATA are combined; surrounding XML whitespace is trimmed; XML entities are already decoded by the dependency; repeated `category` children remain ordered; self-closing elements are valid empty elements.

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

## Dates and errors

RSS and JSON Feed dates remain `String?` values. The parser preserves original RFC 822/RFC 1123 or RFC 3339 text; date parsing and normalization are planned for a later phase.

RSS raises typed errors with paths such as `channel.item[2].enclosure.url`. Invalid XML, unsupported versions, missing channel/title/link/description, invalid enclosure attributes, and missing stable item identity are distinguished. The operation is atomic and does not return partial feeds.

## Verification and growth

The current suite has 27 behavior tests: the original 15 JSON Feed tests plus RSS integration tests for real-world-shaped fixtures and XML dependency behavior. CI runs `moon --version`, `moonc -v`, `moon check`, `moon test`, `moon build`, and the example using the pinned v0.10.14 toolchain series.

Future Atom support should consume the same XML dependency and normalize into the same model. It is intentionally not part of this phase. A future datetime layer must make timezone handling and invalid-date policy explicit before replacing source strings.
