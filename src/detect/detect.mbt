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
fn starts(chars : Array[Char], pos : Int, token : String) -> Bool {
  let value = token.to_array()
  if pos < 0 || pos + value.length() > chars.length() {
    false
  } else {
    let mut matched = true
    for index, ch in value {
      if chars[pos + index] != ch {
        matched = false
      }
    }
    matched
  }
}

///|
fn xml_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn skip_space(chars : Array[Char], pos : Int) -> Int {
  let mut at = pos
  while at < chars.length() && xml_space(chars[at]) {
    at += 1
  }
  at
}

///|
fn find(chars : Array[Char], start : Int, token : String) -> Int? {
  let mut at = start
  while at + token.to_array().length() <= chars.length() {
    if starts(chars, at, token) {
      return Some(at)
    }
    at += 1
  }
  None
}

///|
fn xml_declaration(chars : Array[Char], pos : Int) -> Bool {
  if !starts(chars, pos, "<?xml") {
    false
  } else {
    let next = pos + 5
    next == chars.length() || xml_space(chars[next]) || chars[next] == '?'
  }
}

///|
fn parse_root(
  chars : Array[Char],
  pos : Int,
) -> (String, Map[String, String]) raise DetectError {
  if pos >= chars.length() || chars[pos] != '<' {
    raise MalformedPrefix("expected XML root start tag")
  }
  let mut at = pos + 1
  let name_start = at
  while at < chars.length() &&
        !xml_space(chars[at]) &&
        chars[at] != '/' &&
        chars[at] != '>' {
    at += 1
  }
  if at == name_start {
    raise MalformedPrefix("missing XML root name")
  }
  let name_builder = StringBuilder()
  for index = name_start; index < at; index = index + 1 {
    name_builder.write_char(chars[index])
  }
  let name = name_builder.to_string()
  let attributes : Map[String, String] = Map([])
  while true {
    at = skip_space(chars, at)
    if at >= chars.length() {
      raise MalformedPrefix("unterminated XML root start tag")
    }
    if chars[at] == '>' {
      return (name, attributes)
    }
    if chars[at] == '/' {
      if at + 1 < chars.length() && chars[at + 1] == '>' {
        return (name, attributes)
      }
      raise MalformedPrefix("invalid XML root close")
    }
    let key_start = at
    while at < chars.length() &&
          !xml_space(chars[at]) &&
          chars[at] != '=' &&
          chars[at] != '/' &&
          chars[at] != '>' {
      at += 1
    }
    if at == key_start {
      raise MalformedPrefix("invalid XML root attribute")
    }
    let key_builder = StringBuilder()
    for index = key_start; index < at; index = index + 1 {
      key_builder.write_char(chars[index])
    }
    let key = key_builder.to_string()
    at = skip_space(chars, at)
    if at >= chars.length() || chars[at] != '=' {
      raise MalformedPrefix("expected '=' after XML root attribute")
    }
    at = skip_space(chars, at + 1)
    if at >= chars.length() || (chars[at] != '"' && chars[at] != '\'') {
      raise MalformedPrefix("XML root attribute must be quoted")
    }
    let quote = chars[at]
    at += 1
    let value_start = at
    while at < chars.length() && chars[at] != quote {
      at += 1
    }
    if at >= chars.length() {
      raise MalformedPrefix("unterminated XML root attribute")
    }
    let value_builder = StringBuilder()
    for index = value_start; index < at; index = index + 1 {
      value_builder.write_char(chars[index])
    }
    attributes.set(key, value_builder.to_string())
    at += 1
  } nobreak {
    ("", attributes)
  }
}

///|
/// Lightly classify the input prefix. Full syntax and format validation is left to each parser.
pub fn detect_format(input : String) -> FeedFormat raise DetectError {
  let chars = input.to_array()
  let mut pos = 0
  if !chars.is_empty() && chars[0].to_int() == 0xFEFF {
    pos = 1
  }
  pos = skip_space(chars, pos)
  if pos >= chars.length() {
    raise EmptyInput
  }
  if chars[pos] == '{' {
    return JsonFeed
  }
  if chars[pos] != '<' {
    raise UnknownFormat
  }
  while true {
    pos = skip_space(chars, pos)
    if starts(chars, pos, "<!--") {
      match find(chars, pos + 4, "-->") {
        Some(end) => pos = end + 3
        None => raise MalformedPrefix("unterminated XML comment before root")
      }
    } else if xml_declaration(chars, pos) {
      match find(chars, pos + 5, "?>") {
        Some(end) => pos = end + 2
        None => raise MalformedPrefix("unterminated XML declaration")
      }
    } else {
      break
    }
  }
  pos = skip_space(chars, pos)
  if pos >= chars.length() {
    raise MalformedPrefix("missing XML root element")
  }
  let (root, attributes) = parse_root(chars, pos)
  match root {
    "rss" => Rss
    "feed" =>
      match attributes.get("xmlns") {
        Some(uri) if uri != "http://www.w3.org/2005/Atom" => raise UnknownFormat
        _ => Atom
      }
    "atom:feed" =>
      match attributes.get("xmlns:atom") {
        Some("http://www.w3.org/2005/Atom") => Atom
        _ => raise UnknownFormat
      }
    _ => raise UnknownFormat
  }
}
