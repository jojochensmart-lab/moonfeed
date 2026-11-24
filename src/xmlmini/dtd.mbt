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
  budget : XmlBudget
  references : Map[String, Array[String]]
  all_references : Array[String]
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
  while self.peek() is Some(ch) && (ncname_char(ch) || ch == ':') {
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
fn DtdParser::external_id(
  self : DtdParser,
  public_only? : Bool = false,
) -> Unit raise XmlError {
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
    let public_identifier = self.quoted()
    if !public_identifier
      .to_array()
      .all(ch => {
        (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
        ch == ' ' ||
        ch == '\r' ||
        ch == '\n' ||
        "-'()+,./:=?;!*#@$_%".contains(ch.to_string())
      }) {
      raise Malformed("invalid XML PUBLIC identifier character")
    }
    let separator = self.space()
    if self.peek() is Some('\'' | '"') {
      if !separator {
        raise Malformed("PUBLIC system identifier requires whitespace")
      }
      let _ = self.quoted()
    } else if !public_only {
      raise Malformed("PUBLIC requires a system identifier")
    }
  } else {
    raise Malformed("invalid XML external identifier")
  }
}

///|
fn DtdParser::occurrence(self : DtdParser) -> Unit {
  if self.peek() is Some('?' | '*' | '+') {
    self.pos += 1
  }
}

///|
fn DtdParser::content_particle(
  self : DtdParser,
  depth : Int,
) -> Unit raise XmlError {
  if self.peek() is Some('(') {
    self.content_group(depth + 1, false)
  } else {
    let _ = self.name()
    self.occurrence()
  }
}

///|
fn DtdParser::content_group(
  self : DtdParser,
  depth : Int,
  mixed : Bool,
) -> Unit raise XmlError {
  if depth > 128 {
    raise Malformed("DTD content model nesting limit exceeded")
  }
  self.expect('(')
  ignore(self.space())
  if self.starts("#PCDATA") {
    if !mixed {
      raise Malformed("mixed content is not a child content particle")
    }
    self.expect_text("#PCDATA")
    ignore(self.space())
    let mut children = 0
    while self.peek() is Some('|') {
      self.pos += 1
      ignore(self.space())
      let _ = self.name()
      children += 1
      ignore(self.space())
    }
    self.expect(')')
    if children > 0 {
      self.expect('*')
    } else if self.peek() is Some('*') {
      self.pos += 1
    }
  } else {
    self.content_particle(depth)
    ignore(self.space())
    let mut separator : Char? = None
    while self.peek() is Some('|' | ',' as current) {
      if separator is Some(previous) && previous != current {
        raise Malformed("mixed separators in DTD content group")
      }
      separator = Some(current)
      self.pos += 1
      ignore(self.space())
      self.content_particle(depth)
      ignore(self.space())
    }
    self.expect(')')
    self.occurrence()
  }
}

///|
fn DtdParser::element_decl(self : DtdParser) -> Unit raise XmlError {
  self.expect_text("<!ELEMENT")
  if !self.space() {
    raise Malformed("ELEMENT requires whitespace")
  }
  let _ = self.name()
  if !self.space() {
    raise Malformed("ELEMENT requires a content specification")
  }
  if self.starts("EMPTY") {
    self.expect_text("EMPTY")
  } else if self.starts("ANY") {
    self.expect_text("ANY")
  } else {
    self.content_group(0, true)
  }
  ignore(self.space())
  self.expect('>')
}

///|
fn DtdParser::notation_decl(self : DtdParser) -> Unit raise XmlError {
  self.expect_text("<!NOTATION")
  if !self.space() {
    raise Malformed("NOTATION requires whitespace")
  }
  let _ = self.name()
  if !self.space() {
    raise Malformed("NOTATION requires an external/public identifier")
  }
  self.external_id(public_only=true)
  ignore(self.space())
  self.expect('>')
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
// XML 1.0 section 4.5 resolves character references in EntityValue when the
// declaration is read, while general references are retained for later use.
fn entity_replacement_value(
  raw : String,
  budget : XmlBudget,
  allow_percent? : Bool = false,
) -> String raise XmlError {
  let chars = raw.to_array()
  let result = StringBuilder()
  let mut pos = 0
  while pos < chars.length() {
    if chars[pos] == '%' && !allow_percent {
      raise Malformed(
        "parameter entity reference inside internal declaration is forbidden",
      )
    }
    if chars[pos] != '&' {
      result.write_char(chars[pos])
      pos += 1
      continue
    }
    budget.reference()
    pos += 1
    let name = StringBuilder()
    while pos < chars.length() && chars[pos] != ';' {
      name.write_char(chars[pos])
      pos += 1
    }
    if pos == chars.length() {
      raise Malformed("unterminated entity reference in EntityValue")
    }
    let reference = name.to_string()
    let token = reference.to_array()
    if reference.has_prefix("#") {
      result.write_char(numeric(reference[1:].to_owned()))
    } else {
      if token.is_empty() ||
        !(ncname_start(token[0]) || token[0] == ':') ||
        !token.all(ch => ncname_char(ch) || ch == ':') {
        raise Malformed("invalid entity name in EntityValue")
      }
      result.write_string("&" + reference + ";")
    }
    pos += 1
  }
  result.to_string()
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
    let raw = self.quoted()
    self.budget.charge_work(raw.length() + 1)
    let value = entity_replacement_value(raw, self.budget)
    ignore(self.space())
    self.expect('>')
    // The first declaration is binding. Parameter entities are deliberately
    // not expanded; a reference to one is rejected by subset().
    if !parameter_entity {
      let refs = declared_references(raw, self.budget)
      for reference in refs {
        self.all_references.push(reference)
      }
      if self.entities.get(name) is None {
        self.entities.set(name, Internal(value))
        self.references.set(name, refs)
      }
    }
  } else {
    self.external_id()
    let had_space = self.space()
    let mut unparsed = false
    if self.starts("NDATA") {
      if parameter_entity {
        raise Malformed("NDATA is forbidden for parameter entities")
      }
      if !had_space {
        raise Malformed("NDATA requires preceding whitespace")
      }
      unparsed = true
      self.expect_text("NDATA")
      if !self.space() {
        raise Malformed("NDATA notation requires whitespace")
      }
      let _ = self.name()
      ignore(self.space())
    }
    self.expect('>')
    if !parameter_entity && self.entities.get(name) is None {
      self.entities.set(name, if unparsed { Unparsed } else { External })
    }
  }
}

///|
fn DtdParser::skip_enumeration(
  self : DtdParser,
  notation : Bool,
) -> Unit raise XmlError {
  self.expect('(')
  while true {
    ignore(self.space())
    let start = self.pos
    if notation && !(self.peek() is Some(ch) && (ncname_start(ch) || ch == ':')) {
      raise Malformed("NOTATION enumeration requires XML names")
    }
    while self.peek() is Some(ch) && (ncname_char(ch) || ch == ':') {
      self.pos += 1
    }
    if self.pos == start {
      raise Malformed("empty or invalid ATTLIST enumeration token")
    }
    ignore(self.space())
    if self.peek() is Some(')') {
      self.pos += 1
      return
    }
    self.expect('|')
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
      self.skip_enumeration(false)
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
        self.skip_enumeration(true)
        true
      } else if type_name == "CDATA" {
        false
      } else if [
          "ID", "IDREF", "IDREFS", "ENTITY", "ENTITIES", "NMTOKEN", "NMTOKENS",
        ].contains(type_name) {
        true
      } else {
        raise Malformed("unknown ATTLIST attribute type")
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
    if default_value is Some(value) {
      if value.contains("<") {
        raise Malformed("literal less-than sign in attribute default")
      }
      // Check the AttValue reference syntax even when the element never occurs.
      // Unlike EntityValue, an attribute default may contain a literal percent.
      ignore(entity_replacement_value(value, self.budget, allow_percent=true))
      // XML 1.0 Entity Declared: direct AND indirect default references must
      // already be declared here, even if the element never appears.
      ignore(
        decode_xml_value(value, self.entities, self.budget, attribute_mode=true),
      )
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
    } else if self.starts("<!ELEMENT") {
      self.element_decl()
    } else if self.starts("<!NOTATION") {
      self.notation_decl()
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
  budget : XmlBudget,
  standalone_yes : Bool,
) -> (Int, DtdInfo) raise XmlError {
  let parser : DtdParser = {
    chars,
    pos: start,
    entities: Map([]),
    attributes: Map([]),
    budget,
    references: Map([]),
    all_references: [],
  }
  parser.expect_text("<!DOCTYPE")
  if !parser.space() {
    raise Malformed("DOCTYPE requires a root name")
  }
  let _ = parser.name()
  ignore(parser.space())
  let external_subset = parser.starts("SYSTEM") || parser.starts("PUBLIC")
  if external_subset {
    parser.external_id()
    ignore(parser.space())
  }
  if parser.peek() is Some('[') {
    parser.pos += 1
    parser.subset()
    ignore(parser.space())
  }
  parser.expect('>')
  validate_entity_declarations(
    parser.entities,
    parser.references,
    parser.all_references,
    !external_subset || standalone_yes,
    budget,
  )
  for i = start; i < parser.pos; i = i + 1 {
    if !xml_character(chars[i].to_int()) {
      raise Malformed("invalid XML 1.0 character in DOCTYPE")
    }
  }
  (parser.pos, { entities: parser.entities, attributes: parser.attributes, })
}
