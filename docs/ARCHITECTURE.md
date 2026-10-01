# Architecture

## Boundaries

- Root package `joanna/moonfeed`: public `parse_json_feed` entry point.
- `src/model`: shared `Feed`, `FeedItem`, `Author`, `Attachment`, `FeedLink` types.
- `src/jsonfeed`: JSON decoding, supported-field validation and normalization.
- `examples/basic`: executable example with exhaustive typed error handling.
- `fixtures/jsonfeed` and `fixtures/malformed`: raw JSON strings consumed by tests.

Reserved local directories: `src/detect`, `src/rss`, `src/atom`, `src/datetime`,
`cli`, `fixtures/rss`, `fixtures/atom`. Empty directories are not tracked by Git.
They will become packages only when their implementation exists.

## Data flow and decisions

`String -> core/json AST -> validated fields -> unified Feed`

Parsing and normalization form one atomic operation. A separate raw JSON Feed
model would duplicate the initial field set without serving a current consumer.
The format-specific package owns mapping; the shared model depends on no parser.
There is no I/O, global state, third-party dependency, or format autodetection.

Optional scalars use `String?`; collections use ordered `Array`. Public structs
have readable/constructible fields. Their arrays are mutable: inherited author
arrays are copied so editing one item's authors cannot mutate the feed's authors.
Dates stay as source strings until a dedicated datetime API exists. URLs and
language tags are not semantically validated. HTML is preserved, not sanitized.

`tags` becomes `categories`, and item dates become `published` and `updated`.
Absent item authors/language inherit feed values; explicitly empty authors do not.
Feed categories, feed updated timestamp, and attachments have no implemented JSON
mapping in this phase. `FeedLink` is a reserved type, not yet a field in `Feed`.

## Validation contract

The API raises typed `ParseError` values. Structural errors include a JSON-style
field path. Unsupported versions have their own variant. An invalid supported
field fails the whole operation; there is no implicit dropping of malformed items.
Required fields must exist and have the expected type. An item needs a nonempty
string ID and at least one content representation. Duplicate IDs are rejected.
Unknown and currently unsupported fields are ignored rather than validated.

This is an initial strict subset, not a complete JSON Feed conformance validator.
Numeric ID coercion, deprecated `author`, attachments, RFC 3339 validation, URL
validation, pagination and extension preservation are deferred. Explicit `null`
is a type error for supported fields. Core JSON parser limits apply; additional
input-size limits and streaming are not part of this API.

## Verification and growth

Blackbox tests exercise the root API and typed errors; fixture raw strings are
compiled as test dependencies for backend-independent execution. The example is
built with the project and can be run with `moon run examples/basic`.

CI pins the MoonBit toolchain and core to the locally verified version, then runs
`moon check`, `moon test`, `moon build`, and the example on Ubuntu. Keep generated
interfaces current with `moon info` and code formatted with `moon fmt`.

Future RSS and Atom packages will normalize into the same model. Add parsers and
fixtures together; avoid speculative empty packages. A future datetime layer must
make timezone handling and invalid-date policy explicit before replacing strings.
