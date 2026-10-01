///|
/// A person or organization. Missing metadata is distinct from an empty string.
pub(all) struct Author {
  name : String?
  url : String?
  avatar : String?
} derive(Eq, @debug.Debug)

///|
/// A downloadable resource; numeric metadata is reserved for future parsers.
pub(all) struct Attachment {
  url : String
  mime_type : String
  title : String?
  size_in_bytes : UInt64?
  duration_in_seconds : Double?
} derive(Eq, @debug.Debug)

///|
/// A typed link, reserved for RSS and Atom link relationships.
pub(all) struct FeedLink {
  url : String
  rel : String?
  media_type : String?
} derive(Eq, @debug.Debug)

///|
/// Format-independent item. Dates are preserved strings, not validated timestamps.
pub(all) struct FeedItem {
  id : String
  title : String?
  url : String?
  external_url : String?
  authors : Array[Author]
  summary : String?
  content_text : String?
  content_html : String?
  published : String?
  updated : String?
  language : String?
  categories : Array[String]
  attachments : Array[Attachment]
} derive(Eq, @debug.Debug)

///|
/// Format-independent feed. Collections are ordered and absent collections are empty.
pub(all) struct Feed {
  title : String
  description : String?
  home_page_url : String?
  feed_url : String?
  language : String?
  authors : Array[Author]
  categories : Array[String]
  updated : String?
  items : Array[FeedItem]
} derive(Eq, @debug.Debug)
