# Atom independent conformance vectors

`vectors.mbt` is the canonical fixture source: XML string literals compile identically on wasm-gc and JS without file I/O or generated caches. `rfc_feed` reproduces RFC 4287 §1.1's first example with compact whitespace; `scoped_entry` combines prefix, XML Base/language, source author, XHTML and foreign extension cases. `legacy_feed` intentionally exercises the older permissive API boundary. `entry` wraps focused positive/negative fragments with required metadata.

Assertions live separately in [`atom_conformance_test.mbt`](../../../atom_conformance_test.mbt). Run `moon test --filter 'conformance*'` from the repository root, or run the complete `moon test` and `moon test --target js` suites. The filter is a Moon CLI test-name pattern, not a different parser configuration.

Coverage includes actual metadata and inherited author values, raw/resolved IRI pairs, language override/reset and grammar errors, line-ending/attribute normalization, XML declaration grammar/placement, general PIs, literal namespace comparison, QName/expanded attribute errors, IPv6/IPvFuture, Unicode/private-use contexts, MIME comments/folding/parameter equivalence, email folding, duplicate singletons, external content summaries and malformed XML in extensions.

These are specification-derived project tests, not the full W3C XML conformance suite. DTD rejection is a documented supported-subset boundary, not proof of full XML 1.0 support.
