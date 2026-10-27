///|
priv struct XmlAttributeDecl {
  default_value : String?
  tokenized : Bool
}

///|
priv struct DtdInfo {
  entities : Map[String, DtdEntity]
  attributes : Map[String, Map[String, XmlAttributeDecl]]
}

///|
priv struct DtdParser {
  chars : Array[Char]
  mut pos : Int
  entities : Map[String, DtdEntity]
  attributes : Map[String, Map[String, XmlAttributeDecl]]
}

///|
fn DtdParser::peek(self : DtdParser) -> Char? {
  if self.pos < self.chars.length() {
    Some(self.chars[self.pos])
  } else {
    None
  }
}

///|
fn DtdParser::starts(self : DtdParser, text : String) -> Bool {
  let expected = text.to_array()
  if self.pos + expected.length() > self.chars.length() {
    false
  } else {
    let mut matches = true
    for i, ch in expected {
      if self.chars[self.pos + i] != ch {
        matches = false
      }
    }
    matches
  }
}

///|
fn DtdParser::expect(self : DtdParser, ch : Char) -> Unit raise XmlError {
  if self.peek() != Some(ch) {
    raise Malformed("malformed XML document type declaration")
  }
  self.pos += 1
}

///|
fn DtdParser::expect_text(
  self : DtdParser,
  text : String,
) -> Unit raise XmlError {
  if !self.starts(text) {
    raise Malformed("malformed XML document type declaration")
  }
  self.pos += text.to_array().length()
}

///|
fn DtdParser::space(self : DtdParser) -> Bool {
  let before = self.pos
  while self.peek() is Some(' ' | '\t' | '\r' | '\n') {
    self.pos += 1
  }
  self.pos > before
}

///|
fn DtdParser::name(self : DtdParser) -> String raise XmlError {
  let start = self.pos
  while self.peek() is Some(ch) &&
        ch != ' ' &&
        ch != '\t' &&
        ch != '\r' &&
        ch != '\n' &&
        ch != '>' &&
        ch != '/' &&
        ch != '[' &&
        ch != ']' &&
        ch != '=' &&
        ch != '?' {
    self.pos += 1
  }
  if self.pos == start {
    raise Malformed("expected XML name in document type declaration")
  }
  let builder = StringBuilder()
  for i = start; i < self.pos; i = i + 1 {
    builder.write_char(self.chars[i])
  }
  let result = builder.to_string()
  let name_chars = result.to_array()
  if name_chars.is_empty() ||
    !(ncname_start(name_chars[0]) || name_chars[0] == ':') ||
    !name_chars.all(ch => ncname_char(ch) || ch == ':') {
    raise Malformed("invalid XML name in document type declaration")
  }
  result
}

///|
fn DtdParser::quoted(self : DtdParser) -> String raise XmlError {
  let quote = match self.peek() {
    Some('\'' | '"' as quote) => quote
    _ => raise Malformed("expected quoted XML DTD literal")
  }
  self.pos += 1
  let start = self.pos
  while self.peek() is Some(ch) && ch != quote {
    self.pos += 1
  }
  if self.peek() != Some(quote) {
    raise Malformed("unterminated XML DTD literal")
  }
  let builder = StringBuilder()
  for i = start; i < self.pos; i = i + 1 {
    builder.write_char(self.chars[i])
  }
  self.pos += 1
  builder.to_string()
}

///|
fn DtdParser::external_id(self : DtdParser) -> Unit raise XmlError {
  if self.starts("SYSTEM") {
    self.expect_text("SYSTEM")
    if !self.space() {
      raise Malformed("SYSTEM identifier requires whitespace")
    }
    let _ = self.quoted()
  } else if self.starts("PUBLIC") {
    self.expect_text("PUBLIC")
    if !self.space() {
      raise Malformed("PUBLIC identifier requires whitespace")
    }
    let _ = self.quoted()
    if !self.space() {
      raise Malformed("PUBLIC system identifier requires whitespace")
    }
    let _ = self.quoted()
  } else {
    raise Malformed("invalid XML external identifier")
  }
}

///|
fn DtdParser::skip_declaration(self : DtdParser) -> Unit raise XmlError {
  let mut quote = None
  while true {
    match self.peek() {
      None => raise Malformed("unterminated XML DTD declaration")
      Some(ch) => {
        self.pos += 1
        match quote {
          Some(q) if ch == q => quote = None
          Some(_) => ()
          None if ch == '\'' || ch == '"' => quote = Some(ch)
          None if ch == '>' => return
          None => ()
        }
      }
    }
  }
}

///|
fn DtdParser::skip_until(self : DtdParser, end : String) -> Unit raise XmlError {
  while !self.starts(end) {
    if self.peek() is None {
      raise Malformed("unterminated XML DTD comment or processing instruction")
    }
    self.pos += 1
  }
  self.pos += end.to_array().length()
}

///|
fn DtdParser::comment(self : DtdParser) -> Unit raise XmlError {
  self.expect_text("<!--")
  let value = StringBuilder()
  while !self.starts("-->") {
    if self.starts("--") || self.peek() is None {
      raise Malformed("invalid XML comment in DTD")
    }
    value.write_char(self.chars[self.pos])
    self.pos += 1
  }
  if value.to_string().has_suffix("-") {
    raise Malformed("invalid XML comment in DTD")
  }
  self.pos += 3
}

///|
fn DtdParser::processing_instruction(self : DtdParser) -> Unit raise XmlError {
  self.expect_text("<?")
  let target = self.name()
  if target.to_lower() == "xml" {
    raise Malformed("reserved processing instruction target in DTD")
  }
  if !self.starts("?>") && !(self.peek() is Some(' ' | '\t' | '\r' | '\n')) {
    raise Malformed("processing instruction in DTD requires whitespace")
  }
  self.skip_until("?>")
}

///|
fn DtdParser::entity_decl(self : DtdParser) -> Unit raise XmlError {
  self.expect_text("<!ENTITY")
  if !self.space() {
    raise Malformed("ENTITY declaration requires whitespace")
  }
  let parameter_entity = self.peek() is Some('%')
  if parameter_entity {
    self.pos += 1
    if !self.space() {
      raise Malformed("parameter entity name requires whitespace")
    }
  }
  let name = self.name()
  if !self.space() {
    raise Malformed("entity definition requires whitespace")
  }
  if self.peek() is Some('\'' | '"') {
    let value = self.quoted()
    ignore(self.space())
    self.expect('>')
    // The first declaration is binding. Parameter entities are deliberately
    // not expanded; a reference to one is rejected by subset().
    if !parameter_entity && self.entities.get(name) is None {
      self.entities.set(name, Internal(value))
    }
  } else {
    self.external_id()
    ignore(self.space())
    if self.starts("NDATA") {
      self.expect_text("NDATA")
      if !self.space() {
        raise Malformed("NDATA notation requires whitespace")
      }
      let _ = self.name()
      ignore(self.space())
    }
    self.expect('>')
    if !parameter_entity && self.entities.get(name) is None {
      self.entities.set(name, External)
    }
  }
}

///|
fn DtdParser::skip_enumeration(self : DtdParser) -> Unit raise XmlError {
  self.expect('(')
  let mut depth = 1
  while depth > 0 {
    match self.peek() {
      None => raise Malformed("unterminated ATTLIST enumeration")
      Some('(') => {
        depth += 1
        self.pos += 1
      }
      Some(')') => {
        depth -= 1
        self.pos += 1
      }
      Some(_) => self.pos += 1
    }
  }
}

///|
fn DtdParser::attlist_decl(self : DtdParser) -> Unit raise XmlError {
  self.expect_text("<!ATTLIST")
  if !self.space() {
    raise Malformed("ATTLIST declaration requires whitespace")
  }
  let element_name = self.name()
  let existing = self.attributes.get(element_name).unwrap_or(Map([]))
  let declarations = existing
  while true {
    let had_space = self.space()
    if self.peek() is Some('>') {
      self.pos += 1
      self.attributes.set(element_name, declarations)
      return
    }
    if !had_space {
      raise Malformed("attribute definitions must be separated by whitespace")
    }
    let attribute_name = self.name()
    if !self.space() {
      raise Malformed("attribute type requires whitespace")
    }
    let tokenized = if self.peek() is Some('(') {
      self.skip_enumeration()
      true
    } else {
      let type_start = self.pos
      while self.peek() is Some(ch) &&
            ch != ' ' &&
            ch != '\t' &&
            ch != '\r' &&
            ch != '\n' &&
            ch != '>' {
        self.pos += 1
      }
      if type_start == self.pos {
        raise Malformed("missing ATTLIST attribute type")
      }
      let type_builder = StringBuilder()
      for i = type_start; i < self.pos; i = i + 1 {
        type_builder.write_char(self.chars[i])
      }
      let type_name = type_builder.to_string()
      if type_name == "NOTATION" {
        if !self.space() {
          raise Malformed("NOTATION type requires an enumeration")
        }
        self.skip_enumeration()
        true
      } else {
        type_name != "CDATA"
      }
    }
    if !self.space() {
      raise Malformed("attribute default requires whitespace")
    }
    let default_value = if self.peek() is Some('#') {
      let marker_start = self.pos
      while self.peek() is Some(ch) &&
            ch != ' ' &&
            ch != '\t' &&
            ch != '\r' &&
            ch != '\n' &&
            ch != '>' {
        self.pos += 1
      }
      let marker_builder = StringBuilder()
      for i = marker_start; i < self.pos; i = i + 1 {
        marker_builder.write_char(self.chars[i])
      }
      let marker = marker_builder.to_string()
      if marker == "#FIXED" {
        if !self.space() {
          raise Malformed("#FIXED requires a default value")
        }
        Some(self.quoted())
      } else if marker == "#REQUIRED" || marker == "#IMPLIED" {
        None
      } else {
        raise Malformed("invalid ATTLIST default declaration")
      }
    } else {
      Some(self.quoted())
    }
    if declarations.get(attribute_name) is None {
      declarations.set(attribute_name, { default_value, tokenized, })
    }
  }
}

///|
fn DtdParser::subset(self : DtdParser) -> Unit raise XmlError {
  while true {
    ignore(self.space())
    if self.peek() is Some(']') {
      self.pos += 1
      return
    }
    if self.peek() is None {
      raise Malformed("unterminated internal DTD subset")
    }
    if self.starts("<!--") {
      self.comment()
    } else if self.starts("<?") {
      self.processing_instruction()
    } else if self.starts("<!ENTITY") {
      self.entity_decl()
    } else if self.starts("<!ATTLIST") {
      self.attlist_decl()
    } else if self.starts("<!ELEMENT") || self.starts("<!NOTATION") {
      self.pos += 2
      self.skip_declaration()
    } else if self.peek() is Some('%') {
      raise Malformed("parameter entity references are unsupported")
    } else {
      raise Malformed("unexpected content in internal DTD subset")
    }
  }
}

///|
fn parse_doctype(
  chars : Array[Char],
  start : Int,
) -> (Int, DtdInfo) raise XmlError {
  let parser : DtdParser = {
    chars,
    pos: start,
    entities: Map([]),
    attributes: Map([]),
  }
  parser.expect_text("<!DOCTYPE")
  if !parser.space() {
    raise Malformed("DOCTYPE requires a root name")
  }
  let _ = parser.name()
  ignore(parser.space())
  if parser.starts("SYSTEM") || parser.starts("PUBLIC") {
    parser.external_id()
    ignore(parser.space())
  }
  if parser.peek() is Some('[') {
    parser.pos += 1
    parser.subset()
    ignore(parser.space())
  }
  parser.expect('>')
  (parser.pos, { entities: parser.entities, attributes: parser.attributes, })
}
