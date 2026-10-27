# XML parsing scope for feeds

MoonFeed's `src/xmlmini` package is an internal event reader for RSS and Atom. It is not a general-purpose XML processor, validator, or serializer.

It handles the XML 1.0 syntax used by the feed parsers: element and attribute syntax, quoted values, predefined and numeric character references, CDATA, comments, processing instructions, namespace expansion, line-end normalization, and feed-level document checks. Atom and RSS builders require one complete document element and reject non-whitespace character data outside it.

For an internal `DOCTYPE` subset, the reader expands declared internal general entities that produce text, applies internal `ATTLIST` default values, and performs XML attribute whitespace normalization for declared CDATA and tokenized types. Entity replacement is bounded to 32 nested references and 1 MiB per decoded value. A declared entity whose replacement contains markup is rejected when used because the event reader does not inject replacement markup into the XML event stream.

This is deliberately not complete DTD processing. Parameter-entity references, external subsets, external general entities, DTD content-model/type validity checks, and defaults declared externally are not processed. External identifiers are parsed but never dereferenced. The reader does not perform XML Schema validation. Callers pass decoded text; byte-level encoding detection and conversion are outside this API. These limits mean MoonFeed still does not consume every legal XML 1.0 Atom serialization; see the [Atom compatibility matrix](ATOM_RFC4287_COMPLIANCE.md).
