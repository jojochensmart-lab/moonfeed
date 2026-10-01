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
pub struct Reader {
  chars : Array[Char]
  mut pos : Int
  tags : Array[String]
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
  let _ = self.until("-->")
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
  Text(decode(b.to_string()))
}

///|
fn Reader::attrs(self : Reader) -> Map[String, String] raise XmlError {
  let m : Map[String, String] = Map([])
  while true {
    self.space()
    match self.peek() {
      Some('>' | '/') => return m
      None => raise Malformed("unterminated tag")
      _ => ()
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
  self.space()
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
