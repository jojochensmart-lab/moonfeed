///|
pub struct XmlElement {
  name : String
  attributes : Map[String, String]
}

///|
pub enum XmlEvent {
  Start(XmlElement)
  End(String)
  Empty(XmlElement)
  Text(String)
  CData(String)
  Eof
}

///|
pub(all) suberror XmlError {
  Malformed(String)
}

///|
fn xml_character(n : Int) -> Bool {
  n == 0x9 ||
  n == 0xA ||
  n == 0xD ||
  (n >= 0x20 && n <= 0xD7FF) ||
  (n >= 0xE000 && n <= 0xFFFD) ||
  (n >= 0x10000 && n <= 0x10FFFF)
}

///|
pub struct Reader {
  chars : Array[Char]
  mut pos : Int
  tags : Array[String]
}

///|
/// Namespace-expanded XML element or attribute name.
pub struct ExpandedName {
  namespace_uri : String?
  local_name : String
}

///|
/// Attribute with its namespace-expanded name.
pub struct NamespaceAttribute {
  name : ExpandedName
  value : String
}

///|
/// XML element with namespace-expanded element and attribute names.
pub struct NamespaceElement {
  name : ExpandedName
  attributes : Array[NamespaceAttribute]
}

///|
/// Namespace-aware counterpart to XmlEvent. The legacy event API is unchanged.
pub enum NamespaceEvent {
  NamespaceStart(NamespaceElement)
  NamespaceEnd(ExpandedName)
  NamespaceEmpty(NamespaceElement)
  NamespaceText(String)
  NamespaceCData(String)
  NamespaceEof
}

///|
pub struct NamespaceReader {
  inner : Reader
  scopes : Array[Map[String, String]]
}

///|
pub fn NamespaceReader::from_string(input : String) -> NamespaceReader {
  { inner: Reader::from_string(input), scopes: [], }
}

///|
fn namespace_error(message : String) -> XmlError {
  Malformed("namespace: " + message)
}

///|
fn ncname_start(ch : Char) -> Bool {
  let n = ch.to_int()
  (n >= 0x41 && n <= 0x5A) ||
  n == 0x5F ||
  (n >= 0x61 && n <= 0x7A) ||
  (n >= 0xC0 && n <= 0xD6) ||
  (n >= 0xD8 && n <= 0xF6) ||
  (n >= 0xF8 && n <= 0x2FF) ||
  (n >= 0x370 && n <= 0x37D) ||
  (n >= 0x37F && n <= 0x1FFF) ||
  (n >= 0x200C && n <= 0x200D) ||
  (n >= 0x2070 && n <= 0x218F) ||
  (n >= 0x2C00 && n <= 0x2FEF) ||
  (n >= 0x3001 && n <= 0xD7FF) ||
  (n >= 0xF900 && n <= 0xFDCF) ||
  (n >= 0xFDF0 && n <= 0xFFFD) ||
  (n >= 0x10000 && n <= 0xEFFFF)
}

///|
fn ncname_char(ch : Char) -> Bool {
  let n = ch.to_int()
  ncname_start(ch) ||
  (n >= 0x30 && n <= 0x39) ||
  n == 0x2D ||
  n == 0x2E ||
  n == 0xB7 ||
  (n >= 0x300 && n <= 0x36F) ||
  (n >= 0x203F && n <= 0x2040)
}

///|
fn valid_ncname(name : String) -> Bool {
  let chars = name.to_array()
  if chars.is_empty() || !ncname_start(chars[0]) {
    false
  } else {
    let mut valid = true
    for index = 1; index < chars.length(); index = index + 1 {
      if !ncname_char(chars[index]) {
        valid = false
      }
    }
    valid
  }
}

///|
fn split_qname(name : String) -> (String?, String) raise XmlError {
  let chars = name.to_array()
  let mut colon = -1
  for index, ch in chars {
    if ch == ':' {
      if colon >= 0 {
        raise namespace_error("qualified name has more than one colon")
      }
      colon = index
    }
  }
  if colon < 0 {
    if !valid_ncname(name) {
      raise namespace_error("invalid unprefixed name")
    }
    (None, name)
  } else {
    let prefix_builder = StringBuilder()
    let local_builder = StringBuilder()
    for i, ch in chars {
      if i < colon {
        prefix_builder.write_char(ch)
      } else if i > colon {
        local_builder.write_char(ch)
      }
    }
    let prefix = prefix_builder.to_string()
    let local_part = local_builder.to_string()
    if !valid_ncname(prefix) || !valid_ncname(local_part) {
      raise namespace_error("invalid qualified name")
    }
    (Some(prefix), local_part)
  }
}

///|
fn same_expanded_name(left : ExpandedName, right : ExpandedName) -> Bool {
  left.namespace_uri == right.namespace_uri &&
  left.local_name == right.local_name
}

///|
fn clone_scope(source : Map[String, String]?) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  match source {
    Some(map) =>
      for (prefix, uri) in map.to_array() {
        result.set(prefix, uri)
      }
    None => ()
  }
  result
}

///|
fn expanded_name(
  raw : String,
  scope : Map[String, String],
  is_attribute : Bool,
) -> ExpandedName raise XmlError {
  let (prefix, local_name) = split_qname(raw)
  let namespace_uri = match prefix {
    None =>
      if is_attribute {
        None
      } else {
        match scope.get("") {
          Some(uri) if !uri.is_empty() => Some(uri)
          _ => None
        }
      }
    Some("xml") => Some("http://www.w3.org/XML/1998/namespace")
    Some("xmlns") => raise namespace_error("xmlns prefix is reserved")
    Some(value) =>
      match scope.get(value) {
        Some(uri) if !uri.is_empty() => Some(uri)
        _ => raise namespace_error("undeclared prefix " + value)
      }
  }
  { namespace_uri, local_name, }
}

///|
fn build_namespace_element(
  element : XmlElement,
  parent_scope : Map[String, String]?,
) -> (NamespaceElement, Map[String, String]) raise XmlError {
  let scope = clone_scope(parent_scope)
  scope.set("xml", "http://www.w3.org/XML/1998/namespace")
  for (key, value) in element.attributes.to_array() {
    if key == "xmlns" {
      if value == "http://www.w3.org/XML/1998/namespace" ||
        value == "http://www.w3.org/2000/xmlns/" {
        raise namespace_error("reserved namespace URI cannot be the default")
      }
      scope.set("", value)
    } else if key.has_prefix("xmlns:") {
      let prefix = key[6:].to_owned()
      if !valid_ncname(prefix) || prefix == "xmlns" {
        raise namespace_error("invalid or reserved namespace prefix")
      }
      if value.is_empty() {
        raise namespace_error("a namespace prefix cannot be undeclared")
      }
      if (prefix == "xml" && value != "http://www.w3.org/XML/1998/namespace") ||
        (prefix != "xml" && value == "http://www.w3.org/XML/1998/namespace") ||
        value == "http://www.w3.org/2000/xmlns/" {
        raise namespace_error("reserved prefix or namespace URI binding")
      }
      scope.set(prefix, value)
    }
  }
  let name = expanded_name(element.name, scope, false)
  if element.name.has_prefix("xmlns:") {
    raise namespace_error("element names must not use the xmlns prefix")
  }
  let attributes : Array[NamespaceAttribute] = []
  for (raw_name, value) in element.attributes.to_array() {
    if raw_name != "xmlns" && !raw_name.has_prefix("xmlns:") {
      let attr_name = expanded_name(raw_name, scope, true)
      for existing in attributes {
        if same_expanded_name(existing.name, attr_name) {
          raise namespace_error("duplicate expanded attribute name")
        }
      }
      attributes.push({ name: attr_name, value, })
    }
  }
  ({ name, attributes, }, scope)
}

///|
pub fn NamespaceReader::read_event(
  self : NamespaceReader,
) -> NamespaceEvent raise XmlError {
  match self.inner.read_event() {
    Start(element) => {
      let parent = if self.scopes.is_empty() {
        None
      } else {
        Some(self.scopes[self.scopes.length() - 1])
      }
      let (expanded, scope) = build_namespace_element(element, parent)
      self.scopes.push(scope)
      NamespaceStart(expanded)
    }
    Empty(element) => {
      let parent = if self.scopes.is_empty() {
        None
      } else {
        Some(self.scopes[self.scopes.length() - 1])
      }
      let (expanded, _) = build_namespace_element(element, parent)
      NamespaceEmpty(expanded)
    }
    End(raw_name) => {
      guard self.scopes.pop() is Some(scope) else {
        raise namespace_error("end tag without namespace scope")
      }
      NamespaceEnd(expanded_name(raw_name, scope, false))
    }
    Text(value) => NamespaceText(value)
    CData(value) => NamespaceCData(value)
    Eof => NamespaceEof
  }
}

///|
pub fn Reader::from_string(input : String) -> Reader {
  { chars: input.to_array(), pos: 0, tags: [], }
}

///|
fn Reader::peek(self : Reader) -> Char? {
  if self.pos < self.chars.length() {
    Some(self.chars[self.pos])
  } else {
    None
  }
}

///|
fn Reader::starts(self : Reader, s : String) -> Bool {
  let a = s.to_array()
  if self.pos + a.length() > self.chars.length() {
    false
  } else {
    let mut ok = true
    for i, c in a {
      if self.chars[self.pos + i] != c {
        ok = false
      }
    }
    ok
  }
}

///|
fn Reader::take(self : Reader) -> Char raise XmlError {
  match self.peek() {
    Some(c) => {
      if !xml_character(c.to_int()) {
        raise Malformed("invalid XML 1.0 character")
      }
      self.pos += 1
      c
    }
    None => raise Malformed("unexpected end")
  }
}

///|
fn Reader::expect(self : Reader, c : Char) -> Unit raise XmlError {
  if self.take() != c {
    raise Malformed("unexpected XML character")
  }
}

///|
fn Reader::space(self : Reader) -> Unit {
  while self.peek() is Some(' ' | '\t' | '\r' | '\n') {
    self.pos += 1
  }
}

///|
fn Reader::name(self : Reader) -> String raise XmlError {
  let start = self.pos
  while self.peek() is Some(c) &&
        c != ' ' &&
        c != '\t' &&
        c != '\r' &&
        c != '\n' &&
        c != '/' &&
        c != '>' &&
        c != '=' &&
        c != '?' {
    self.pos += 1
  }
  if self.pos == start {
    raise Malformed("expected name")
  }
  let b = StringBuilder()
  for i = start; i < self.pos; i = i + 1 {
    b.write_char(self.chars[i])
  }
  b.to_string()
}

///|
fn digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn numeric(s : String) -> Char raise XmlError {
  let a = s.to_array()
  let mut radix = 10
  let mut i = 0
  if a.length() > 1 && a[0] == 'x' {
    radix = 16
    i = 1
  }
  if i == a.length() {
    raise Malformed("empty numeric entity")
  }
  let mut n = 0
  for j = i; j < a.length(); j = j + 1 {
    let d = match digit(a[j]) {
      Some(d) if d < radix => d
      _ => raise Malformed("invalid numeric entity")
    }
    if n > 0x10FFFF / radix {
      raise Malformed("numeric entity out of range")
    }
    n = n * radix + d
    if n > 0x10FFFF {
      raise Malformed("numeric entity out of range")
    }
  }
  if !xml_character(n) {
    raise Malformed("numeric entity is not an XML 1.0 character")
  }
  match n.to_char() {
    Some(c) => c
    None => raise Malformed("invalid Unicode scalar")
  }
}

///|
fn decode(s : String) -> String raise XmlError {
  let a = s.to_array()
  let b = StringBuilder()
  let mut i = 0
  while i < a.length() {
    if a[i] != '&' {
      b.write_char(a[i])
      i += 1
    } else {
      let start = i + 1
      i = start
      while i < a.length() && a[i] != ';' {
        i += 1
      }
      if i == a.length() {
        raise Malformed("unterminated entity")
      }
      let e = StringBuilder()
      for j = start; j < i; j = j + 1 {
        e.write_char(a[j])
      }
      match e.to_string() {
        "amp" => b.write_char('&')
        "lt" => b.write_char('<')
        "gt" => b.write_char('>')
        "quot" => b.write_char('"')
        "apos" => b.write_char('\'')
        x if x.has_prefix("#") => b.write_char(numeric(x[1:].to_owned()))
        _ => raise Malformed("unsupported entity")
      }
      i += 1
    }
  }
  b.to_string()
}

///|
fn Reader::until(self : Reader, end : String) -> String raise XmlError {
  let n = end.to_array().length()
  let b = StringBuilder()
  while !self.starts(end) {
    b.write_char(self.take())
  }
  self.pos += n
  b.to_string()
}

///|
fn Reader::comment(self : Reader) -> Unit raise XmlError {
  self.pos += 4
  let value = self.until("-->")
  if value.contains("--") || value.has_suffix("-") {
    raise Malformed("invalid XML comment")
  }
}

///|
fn Reader::declaration(self : Reader) -> Unit raise XmlError {
  self.pos += 2
  if self.name() != "xml" {
    raise Malformed("processing instructions unsupported")
  }
  let _ = self.until("?>")
}

///|
fn Reader::text(self : Reader) -> XmlEvent raise XmlError {
  let b = StringBuilder()
  while self.peek() is Some(c) && c != '<' {
    b.write_char(self.take())
  }
  let value = b.to_string()
  if value.contains("]]>") {
    raise Malformed("CDATA close delimiter in ordinary text")
  }
  Text(decode(value))
}

///|
fn Reader::attrs(self : Reader) -> Map[String, String] raise XmlError {
  let m : Map[String, String] = Map([])
  while true {
    let before_space = self.pos
    self.space()
    match self.peek() {
      Some('>' | '/') => return m
      None => raise Malformed("unterminated tag")
      _ => ()
    }
    if before_space == self.pos {
      raise Malformed("attributes must be separated by whitespace")
    }
    let k = self.name()
    self.space()
    self.expect('=')
    self.space()
    let q = self.take()
    if q != '\'' && q != '"' {
      raise Malformed("attribute must be quoted")
    }
    let b = StringBuilder()
    while self.peek() is Some(c) && c != q {
      if c == '<' {
        raise Malformed("invalid attribute")
      }
      b.write_char(self.take())
    }
    self.expect(q)
    if m.get(k) is Some(_) {
      raise Malformed("duplicate attribute")
    }
    m.set(k, decode(b.to_string()))
  } nobreak {
    m
  }
}

///|
fn Reader::start(self : Reader) -> XmlEvent raise XmlError {
  self.expect('<')
  let n = self.name()
  let a = self.attrs()
  self.space()
  if self.peek() is Some('/') {
    self.pos += 1
    self.expect('>')
    Empty({ name: n, attributes: a, })
  } else {
    self.expect('>')
    self.tags.push(n)
    Start({ name: n, attributes: a, })
  }
}

///|
fn Reader::finish(self : Reader) -> XmlEvent raise XmlError {
  self.expect('<')
  self.expect('/')
  let n = self.name()
  self.space()
  self.expect('>')
  match self.tags.pop() {
    Some(open) if open == n => End(n)
    Some(_) => raise Malformed("mismatched end tag")
    None => raise Malformed("unexpected end tag")
  }
}

///|
pub fn Reader::read_event(self : Reader) -> XmlEvent raise XmlError {
  while self.starts("<!--") {
    self.comment()
  }
  if self.pos == self.chars.length() {
    if !self.tags.is_empty() {
      raise Malformed("unclosed element")
    }
    return Eof
  }
  if self.starts("<?") {
    self.declaration()
    return self.read_event()
  }
  if self.starts("<![CDATA[") {
    self.pos += 9
    return CData(self.until("]]>"))
  }
  if self.starts("</") {
    return self.finish()
  }
  if self.peek() is Some('<') {
    if self.starts("<!") {
      raise Malformed("declarations unsupported")
    }
    return self.start()
  }
  self.text()
}
