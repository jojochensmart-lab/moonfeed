///|
/// RSS errors carry a field path, or an XML location from the underlying reader.
pub(all) suberror ParseError {
  InvalidXml(String)
  UnsupportedRssVersion(String)
  MissingChannel
  MissingChannelTitle
  MissingChannelLink
  MissingChannelDescription
  InvalidEnclosure(String, String)
  InvalidRequiredField(String, String)
} derive(Eq, @debug.Debug)

///|
pub fn ParseError::equal(self : ParseError, other : ParseError) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn ParseError::not_equal(self : ParseError, other : ParseError) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn ParseError::to_repr(self : ParseError) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
pub(all) struct Category {
  value : String
  domain : String?
}

///|
pub(all) struct Guid {
  value : String
  is_permalink : Bool
}

///|
pub(all) struct Enclosure {
  url : String
  mime_type : String
  length : UInt64
}

///|
pub(all) struct Source {
  title : String
  url : String
}

///|
pub(all) struct Image {
  url : String
  title : String
  link : String
  width : UInt64?
  height : UInt64?
  description : String?
}

///|
/// RSS-specific metadata retained before normalization; dates stay as source strings.
pub(all) struct Item {
  title : String?
  link : String?
  description : String?
  author : String?
  categories : Array[Category]
  comments : String?
  enclosure : Enclosure?
  guid : Guid?
  pub_date : String?
  source : Source?
}

///|
/// Lossless representation of the supported RSS core fields.
pub(all) struct Channel {
  title : String
  link : String
  description : String
  language : String?
  pub_date : String?
  last_build_date : String?
  managing_editor : String?
  web_master : String?
  categories : Array[Category]
  generator : String?
  docs : String?
  ttl : UInt64?
  image : Image?
  items : Array[Item]
}
