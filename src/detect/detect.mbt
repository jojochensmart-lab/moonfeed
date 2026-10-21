///|
pub(all) enum FeedFormat {
  JsonFeed
  Rss
  Atom
} derive(Eq, @debug.Debug)

///|
pub fn FeedFormat::equal(self : FeedFormat, other : FeedFormat) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn FeedFormat::not_equal(self : FeedFormat, other : FeedFormat) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn FeedFormat::to_repr(self : FeedFormat) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
pub(all) suberror DetectError {
  EmptyInput
  UnknownFormat
  MalformedPrefix(String)
} derive(Eq, @debug.Debug)

///|
pub fn DetectError::equal(self : DetectError, other : DetectError) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn DetectError::not_equal(self : DetectError, other : DetectError) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn DetectError::to_repr(self : DetectError) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
fn xml_whitespace(value : String) -> Bool {
  let mut is_space = true
  for ch in value.to_array() {
    if ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n' {
      is_space = false
    }
  }
  is_space
}

///|
fn classify_root(name : @xmlmini.ExpandedName) -> FeedFormat raise DetectError {
  match (name.namespace_uri, name.local_name) {
    (None, "rss") => Rss
    (Some("http://www.w3.org/2005/Atom"), "feed" | "entry") => Atom
    _ => raise UnknownFormat
  }
}

///|
/// Lightly classify the input prefix. Full syntax and format validation is left to each parser.
pub fn detect_format(input : String) -> FeedFormat raise DetectError {
  let normalized = if input.has_prefix("\u{FEFF}") {
    input["\u{FEFF}".length():].to_owned()
  } else {
    input
  }
  let prefix = normalized.trim_start(chars=" \t\r\n")
  if prefix.is_empty() {
    raise EmptyInput
  }
  if prefix.has_prefix("{") {
    return JsonFeed
  }
  if !prefix.has_prefix("<") {
    raise UnknownFormat
  }
  let reader = @xmlmini.NamespaceReader::from_string(normalized)
  while true {
    let event = reader.read_event() catch {
      _ => raise MalformedPrefix("malformed XML namespace or root tag")
    }
    match event {
      @xmlmini.NamespaceText(value) if xml_whitespace(value) => ()
      @xmlmini.NamespaceStart(element) | @xmlmini.NamespaceEmpty(element) =>
        return classify_root(element.name)
      @xmlmini.NamespaceEof => raise EmptyInput
      _ => raise MalformedPrefix("expected an XML document element")
    }
  } nobreak {
    raise EmptyInput
  }
}
