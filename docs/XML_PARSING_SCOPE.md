# XML parsing scope for feeds

MoonFeed's `src/xmlmini` package is an internal event reader for RSS and Atom. It is not a general-purpose XML processor or validator.

It handles the XML 1.0 syntax used by the feed parsers: element and attribute syntax, quoted values, predefined and numeric character references, CDATA, comments, processing instructions, namespace expansion, line-end normalization, and feed-level well-formedness checks. Atom and RSS document builders require exactly one complete document element and reject non-whitespace character data outside it.

The reader rejects `DOCTYPE` declarations. It does not parse internal or external subsets, expand declared general or parameter entities, apply DTD attribute defaults, validate DTD content models, fetch external identifiers, or perform schema validation. In particular, it never dereferences an external entity or DTD URL. Callers pass decoded text; byte-level encoding detection and conversion are outside this API.

This boundary avoids hidden network access and external-entity expansion while keeping feed parsing deterministic. It also means MoonFeed does not accept every XML 1.0 document that uses DTD features; the Atom RFC matrix records that as a remaining conformance gap. Any future DTD support needs a separate design for entity expansion limits, parameter entities, external identifiers, and well-formedness constraints before implementation.
