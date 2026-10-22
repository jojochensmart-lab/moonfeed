# RFC 4287 Atom compatibility audit

The final target is parsing and semantic processing of both RFC 4287 Feed Documents and standalone Entry Documents. This is an implementation audit, not a claim of full conformance. PASS means the narrowly stated requirement has implementation and test evidence; PARTIAL and FAIL identify remaining work.

## API scope and compatibility

The matrix applies to the new parse_atom_document and parse_atom_document_with_base APIs on Git main. They validate the implemented normative rules and return an AtomDocument with distinct FeedDocument and EntryDocument variants. They preserve Atom-specific metadata and an expanded-name XML tree. They are not included in the already published 0.1.2; this work prepares candidate 0.2.0 pending release gates.

The existing parse_atom and unified parse APIs retain their Feed return types and historical common-field normalization behavior. They are not full RFC validators, do not accept an Entry root as a synthetic Feed, and can accept legacy inputs that the document API rejects. All 117 baseline tests remain unchanged; 21 independent conformance tests are present after the final namespace URI vectors. See [API compatibility](API_COMPATIBILITY.md). Applications requiring the validation and metadata audited below should migrate to the document API; see README. This deliberate compatibility boundary must not be mistaken for full standards validation across all entry points.

References: [RFC 4287](https://www.rfc-editor.org/rfc/rfc4287), [Namespaces in XML 1.0](https://www.w3.org/TR/xml-names/), [XML Base second edition](https://www.w3.org/TR/xmlbase/), [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986), [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987), [RFC 3339](https://www.rfc-editor.org/rfc/rfc3339).

## Normative requirements and evidence

Tests below are in atom_document_test.mbt unless a different path is named. A row is not a percentage of the standard: rows have different sizes and risk.

| ID / standard section | Requirement | Status | Test evidence and remaining work |
| --- | --- | --- | --- |
| A01 / RFC 4287 §§1.2–1.3 | Identify Atom by namespace URI and local name, independent of prefix spelling. | PASS | strict Atom Entry arbitrary prefix is equivalent and foreign roots fail; strict Atom Unicode QName prefixes and XML character errors; original namespace equivalence tests. |
| A02 / W3C Namespaces §§3–6 | Scope/rebind prefixes, reset defaults, reserve xml/xmlns, distinguish unprefixed attributes, reject duplicate expanded attributes. | PASS | Original src/xmlmini/reader_test.mbt namespace scope, attribute and reserved-binding tests; supplementary Unicode prefix test. |
| A03 / W3C Namespaces §3 | Validate namespace declaration URI-reference lexical rules in all cases. | PARTIAL | `src/xmlmini/namespace_uri.mbt` now checks ASCII URI-reference characters and escapes, scheme syntax, relative first-segment colons, authority/userinfo/host/port structure, and bracket placement. Positive and negative conformance vectors cover schemes, relative references, authority, query/fragment, percent escapes and malformed delimiters. Namespace identity remains exact after XML attribute decoding, without URL normalization. Full IP-literal validation and every URI path production remain incomplete. |
| A04 / RFC 4287 §2 | Represent both Feed Document and standalone Entry Document roots without inventing a feed. | PASS | strict Atom Feed and Entry Documents keep distinct root variants; standalone Entry metadata/content test; examples/atom. |
| A05 / RFC 4287 §2, XML 1.0 | Consume all legal XML 1.0 Atom serializations and enforce complete well-formedness. | PARTIAL | `src/xmlmini/reader.mbt` handles XML 1.0 line endings, CDATA/text references, literal attribute whitespace, names, declaration syntax/order/position and general PI skipping. Conformance XML declaration/normalization/PI/malformed tests assert values and errors. DTD/internal declared entities and DTD-based attribute defaults/types remain unsupported; complete XML well-formedness coverage is not claimed. No C14N or schema validator is required. |
| A06 / RFC 4287 §2, XML Base §§3–4 | Inherit/override per-element bases; use retrieval URI; handle empty and fragment bases; preserve original references. | PASS | XML Base nesting resolves links persons generator and content src; retrieval URI and sibling scope restoration; same document references empty base and LEIRI spaces. IDs remain unchanged. |
| A07 / RFC 3986 §§5.2–5.4 | Resolve references by components, path merge and dot-segment removal, including queries/fragments. | PASS | RFC3986 normal reference resolution examples and abnormal reference resolution tests, including percent-encoded dots, empty query/fragment, authority and absolute paths. |
| A08 / RFC 4287 §2, RFC 3987 | Validate all URI/IRI lexical productions and context restrictions. | PARTIAL | `src/atom/ip_literal.mbt` and iri.mbt now validate IPv6 compression/group counts/embedded IPv4, IPvFuture, RFC3987 ucschar and query-only private-use ranges. Conformance IRI IP/Unicode positive and negative vectors pass. Exhaustive LEIRI productions and independent coverage of all IRI component combinations remain incomplete. No resource is dereferenced. |
| A09 / RFC 4287 §2 | Inherit xml:lang, override it and reset it with an empty value. | PASS | XML language inheritance override reset and source language checks feed/entry/text/content/source values. |
| A10 / RFC 4287 §2, §4.2.7.4; RFC3066 §2.1 | Validate the referenced language-tag syntax in xml:lang (including empty reset) and hreflang. | PASS | `src/atom/language.mbt`: structured 1–8 ALPHA primary and 1–8 ALPHA/DIGIT subtags, inherited/overridden/reset values preserved. Conformance RFC3066 valid/boundary/private/historic, invalid language, hreflang and scoped Entry tests assert values and field errors. This is syntax validation, not verification of ISO/IANA assignments or a claim of modern BCP47 registry validation. Legacy APIs remain permissive. |
| A11 / RFC 4287 §3.1 | Apply text/html/xhtml type rules; require one XHTML namespace div and preserve mixed text/markup. | PASS | strict Atom text HTML and XHTML preserve content and validate shape; content XHTML wrapper is excluded from content children, retained in raw. Nonempty title is a SHOULD, not a hard requirement. |
| A12 / RFC 4287 §3.2 | Require exactly one person name, at most one URI/email, retain contributors separately. | PASS | Person construct count/error tests and source metadata test; name/URI/email and extension tree are retained. |
| A13 / RFC 4287 §3.2.3, RFC 2822 | Validate all addr-spec productions, including obsolete forms. | PARTIAL | `src/atom/email.mbt` + media.mbt header_characters reject bare CR/LF and malformed CRLF folds; conformance email folding tests add positive and field-specific negative assertions to existing dot-atom/quoted/comment/domain-literal tests. Complete obsolete control-character/FWS productions remain unsupported; comment depth is limited to 32. |
| A14 / RFC 4287 §3.3 | Enforce uppercase T/Z, calendar/offset/date grammar; preserve fractional precision and offset convention. | PASS | Strict date negative cases, timezone-equivalent dates, fractional digits, year 0000 and -00:00 tests. AtomDate retains raw, fractional_digits and unknown_local_offset. |
| A15 / RFC 4287 §3.3, RFC 3339 | Handle announced positive leap seconds and maintain announcement data. | PARTIAL | 2016 leap second with +01:00 is accepted and flagged; an unannounced date is rejected. The public-domain IANA/IERS transition table is embedded through 2017-01-01 and needs updates for future announcements; no negative leap has occurred. POSIX seconds coincide with the next second, so raw/leap_second/fractional_digits must be retained for exact identity. |
| A16 / RFC 4287 §4.1.1 | Enforce feed id/title/updated, singleton metadata and metadata-before-entry structure. | PASS | Required fields and absolute IDs; duplicate single metadata fields; feed metadata after entries; official §1.1 Feed example. |
| A17 / RFC 4287 §4.1.2 | Enforce entry id/title/updated, singleton content/published/rights/source/summary and allowed container structure. | PASS | Entry required and duplicate-field tests; distinct-root and invalid-container tests. |
| A18 / RFC 4287 §§4.1.1–4.1.2, §4.2.1 | Apply entry -> source -> feed author precedence and feed author presence exception. | PASS | Author conditions/source inheritance and feed author exception tests. A source author alone does not satisfy the feed's exception requiring each entry's own author. |
| A19 / RFC 4287 §4.2.6 | Require absolute IDs, retain exact character identity, allow repeated IDs representing versions. | PASS | Required absolute-ID test preserves case, percent spelling and fragment; repeated entry IDs remain ordered and are not rejected. Full IRI grammar is separately PARTIAL at A08. |
| A20 / RFC 4287 §§4.1.1–4.1.2, §4.2.7 | Apply relation semantics, alternate uniqueness and preserve all link attributes. | PARTIAL | `src/atom/document.mbt` strict_links and media.mbt implement default/IANA alternate relation, language syntax/case-insensitive comparison, type/subtype/parameter-name case, charset case, quoted-value and parameter-order equivalence. Conformance hreflang/MIME tests prove duplicates are rejected while distinct case-sensitive profile values survive. Unknown MIME parameter-specific equivalence rules are not guessed, so universal registered-type semantic equivalence remains incomplete. Raw attributes and length_raw remain retained; UInt64 conversion is optional. |
| A21 / RFC 4287 §4.2.2 | Require category term and retain scheme/label without inventing category meanings. | PASS | Source category metadata and empty-term tests. Scheme must be absolute; IRI lexical limitations are recorded at A08. |
| A22 / RFC 4287 §4.1.3 | Process text/HTML/XHTML/XML/text-MIME/binary content and src; require summaries where mandated. | PASS | Content src/emptiness/type/summary tests; XHTML wrapper test; XML tree and decoded Base64 byte assertions. External src with no type stays unknown rather than inventing a media type. Full MIME syntax is separately PARTIAL at A23. |
| A23 / RFC 4287 §§4.1.3.1, 4.2.7 | Validate complete MIME media-type syntax. | PARTIAL | `src/atom/media.mbt` parses full ASCII token characters, comments/CFWS, quoted-pairs and parameters; content classification and summary requirements share its parsed essence. Conformance MIME tests assert comments/folding, parameter equivalence, raw preservation and invalid inputs. Historical RFC822 control-character/obsolete folding edge productions and arbitrary registered-parameter semantics remain incomplete. Composite rejection applies only to content, not link types. |
| A24 / RFC 4287 §§4.2.4–4.2.5, 4.2.8, 4.2.10 | Retain generator/version/URI, icon/logo, rights; inherit feed rights for entries. | PASS | Source/generator/icon/logo/XML Base and inherited-rights tests; original values and resolved references are retained. |
| A25 / RFC 4287 §4.2.11 | Preserve source metadata with optional id/title/updated and reusable validation rules. | PASS | Source metadata, optional source author-only case and duplicate source-title errors. |
| A26 / RFC 4287 §§5.1, 6 | Isolate and retain foreign/unknown markup; tolerate signatures without requiring verification. | PASS | Extension/signature/repeated-ID test and original collision tests. Expanded-name trees retain semantic content/attributes/base/language, not original prefixes, comments, PI or byte-for-byte serialization. Signature verification/decryption is not provided. |
| A27 / RFC 4287 normative constraints | Give typed errors with field paths for validated rules; do not promote SHOULD guidance into MUST rejection. | PARTIAL | New conformance negatives assert InvalidXml / InvalidAtomRoot / InvalidRequiredField and specific semantic paths in atom_conformance_test.mbt. Existing empty-title, repeated-ID, missing-self-link and signature acceptance tests remain unchanged. Full error/acceptance coverage still depends on A03/A05/A08/A13/A15/A20/A23; full validation is not claimed. |

Counts: 19 PASS, 8 PARTIAL, 0 FAIL (27 rows). A10 changed only after code and positive/negative tests; other broad rows stay PARTIAL. Baseline nine-row audit and implementation/risk decisions: [third-round audit](ATOM_ROUND3_AUDIT.md).

### Implementation locations for every PASS row

| Rows | Implementation | Test files |
| --- | --- | --- |
| A01, A02 | xmlmini/reader.mbt expanded_name/build_namespace_element; atom/parser.mbt named | src/xmlmini/reader_test.mbt, atom_document_test.mbt, atom_conformance_test.mbt |
| A04 | atom/document.mbt strict_document; document_types.mbt AtomDocument | atom_document_test.mbt, atom_conformance_test.mbt; examples/atom/main.mbt |
| A06, A07 | atom/parser.mbt make_node; atom/iri.mbt resolve_iri/remove_dot_segments | atom_document_test.mbt RFC3986 normal/abnormal and XML Base tests; atom_conformance_test.mbt scoped/retrieval fixtures |
| A09, A10 | atom/parser.mbt make_node; atom/language.mbt; document.mbt strict_links/strict_document | atom_document_test.mbt inheritance/reset; atom_conformance_test.mbt language/hreflang/scoped tests |
| A11 | atom/document.mbt strict_text/xhtml_div | atom_document_test.mbt text/HTML/XHTML; atom_conformance_test.mbt scoped Entry |
| A12 | atom/document.mbt strict_person/strict_people | atom_document_test.mbt person counts/source; atom_conformance_test.mbt contributors |
| A14 | atom/document.mbt date_value; atom/date.mbt atom_date | atom_document_test.mbt dates, fractions, year zero, offsets |
| A16, A17, A18 | atom/document.mbt metadata/container_structure/strict_entry/strict_document | atom_document_test.mbt required/singleton/author/structure tests; atom_conformance_test.mbt Feed/Entry/duplicate paths |
| A19 | atom/document.mbt absolute_iri/metadata; document_types.mbt | atom_document_test.mbt exact ID/repeated versions; atom_conformance_test.mbt prefixed Entry ID |
| A21 | atom/document.mbt strict_categories | atom_document_test.mbt source/category empty-term/required-term tests |
| A22 | atom/document.mbt strict_content/decode_base64/strict_entry | atom_document_test.mbt content/MIME/Base64/src; atom_conformance_test.mbt MIME/src |
| A24, A25 | atom/document.mbt metadata/strict_entry | atom_document_test.mbt source/rights/generator/icon/logo; atom_conformance_test.mbt source author |
| A26 | atom/document.mbt markup/container_structure; parser.mbt expanded-name filtering | atom_document_test.mbt extensions/signatures; atom_conformance_test.mbt extension isolation |

Paths above are relative to src/ unless they identify a test or example. Some PASS rows depend on lexical productions separately marked PARTIAL; their narrow PASS does not erase those dependencies.

## Reproduction and compatibility boundary

Run moon check, moon test, moon build and moon run examples/atom with MoonBit >= v0.10.14. The current local result is 138/138 on both default and JS targets: the original 117 baseline tests plus 21 independent conformance tests. Test fixtures and reproduction details are in [fixtures/atom/conformance](../fixtures/atom/conformance/README.md). The Atom example verifies equivalent default/prefixed standalone Entry Documents and prints:

~~~text
Equivalent Entry Documents: PASS
urn:entry:demo
../article
https://example.org/article
~~~

The IANA/IERS leap-transition data is [public domain](https://data.iana.org/time-zones/tzdb/leap-seconds.list). It is data, not a registry/package dependency.

## Remaining work before an unqualified full-conformance claim

1. Complete the remaining XML 1.0 document/DTD behavior and full RFC 3986 IP-literal/URI component validation; validate with external XML and URI conformance vectors.
2. Complete remaining LEIRI/namespace-URI/email/MIME productions and registered-parameter link comparison rules, keeping MUST/SHOULD distinctions and extension tolerance.
3. Expand independent normative fixtures, automate leap-table maintenance, and decide a versioned migration policy for strict validation on legacy normalization entry points.

The new document API materially closes the standalone Entry, XML Base, metadata-loss and core cardinality gaps. The remaining rows prevent a full RFC 4287 claim. This audit alone does not establish hackathon acceptance.
