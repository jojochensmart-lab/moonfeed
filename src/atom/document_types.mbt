///|
/// Expanded-name XML infoset retained for XHTML, XML content and extensions.
pub(all) struct Markup {
  namespace_uri : String?
  local_name : String
  attributes : Array[MarkupAttribute]
  content : Array[MarkupContent]
  base_uri : String?
  language : String?
}

///|
pub(all) struct MarkupAttribute {
  namespace_uri : String?
  local_name : String
  value : String
}

///|
pub(all) enum MarkupContent {
  Text(String)
  Element(Markup)
}

///|
pub(all) struct AtomText {
  kind : String
  value : String
  xhtml : Markup?
  language : String?
  base_uri : String?
}

///|
pub(all) struct AtomPerson {
  name : String
  uri : IriReference?
  email : String?
  raw : Markup
}

///|
pub(all) struct AtomCategory {
  term : String
  scheme : IriReference?
  label : String?
  raw : Markup
}

///|
pub(all) struct AtomLink {
  href : IriReference
  rel : String
  media_type : String?
  hreflang : String?
  title : String?
  length : UInt64?
  length_raw : String?
  raw : Markup
}

///|
pub(all) struct AtomGenerator {
  value : String
  uri : IriReference?
  version : String?
}

///|
/// RFC 3339 source precision and offset/leap conventions are retained explicitly.
pub(all) struct AtomDate {
  raw : String
  unix_seconds : Int64
  fractional_digits : String?
  leap_second : Bool
  unknown_local_offset : Bool
}

///|
/// Feed/source/entry metadata. Source may omit id, title and updated.
pub(all) struct AtomMetadata {
  id : String?
  title : AtomText?
  updated : AtomDate?
  authors : Array[AtomPerson]
  contributors : Array[AtomPerson]
  categories : Array[AtomCategory]
  links : Array[AtomLink]
  rights : AtomText?
  subtitle : AtomText?
  generator : AtomGenerator?
  icon : IriReference?
  logo : IriReference?
  raw : Markup
}

///|
pub(all) struct AtomContent {
  media_type : String?
  value : String
  decoded_bytes : Array[Byte]?
  src : IriReference?
  markup : Array[MarkupContent]
  raw : Markup
  language : String?
  base_uri : String?
}

///|
pub(all) struct AtomEntry {
  metadata : AtomMetadata
  published : AtomDate?
  summary : AtomText?
  content : AtomContent?
  source : AtomMetadata?
  effective_authors : Array[AtomPerson]
  effective_rights : AtomText?
}

///|
pub(all) struct AtomFeed {
  metadata : AtomMetadata
  entries : Array[AtomEntry]
}

///|
/// Feed and Entry Documents remain distinct; no synthetic feed is constructed.
pub(all) enum AtomDocument {
  FeedDocument(AtomFeed)
  EntryDocument(AtomEntry)
}
