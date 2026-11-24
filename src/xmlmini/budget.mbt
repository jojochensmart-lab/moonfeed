///|
priv struct XmlLimits {
  depth : Int
  references : Int
  work : Int
  output_bytes : Int
  input_bytes : Int
  element_depth : Int
}

///|
fn xml_limits() -> XmlLimits {
  {
    depth: 32,
    references: 65_536,
    work: 16_777_216,
    output_bytes: 8_388_608,
    input_bytes: 16_777_216,
    element_depth: 256,
  }
}

///|
priv struct XmlBudget {
  limits : XmlLimits
  mut references : Int
  mut work : Int
  mut output_bytes : Int
  mut failure : String?
}

///|
fn new_budget(limits : XmlLimits) -> XmlBudget {
  {
    limits,
    references: limits.references,
    work: limits.work,
    output_bytes: limits.output_bytes,
    failure: None,
  }
}

///|
fn XmlBudget::fail(self : XmlBudget, message : String) -> Unit raise XmlError {
  self.failure = Some(message)
  raise Malformed(message)
}

///|
fn XmlBudget::check(self : XmlBudget) -> Unit raise XmlError {
  if self.failure is Some(message) {
    raise Malformed(message)
  }
}

///|
fn XmlBudget::charge_work(
  self : XmlBudget,
  amount : Int,
) -> Unit raise XmlError {
  self.check()
  if amount > self.work {
    self.fail("XML expansion work limit exceeded")
  }
  self.work -= amount
}

///|
fn XmlBudget::reference(self : XmlBudget) -> Unit raise XmlError {
  self.check()
  if self.references == 0 {
    self.fail("XML entity reference limit exceeded")
  }
  self.references -= 1
}

///|
fn utf8_width(ch : Char) -> Int {
  let n = ch.to_int()
  if n <= 0x7F {
    1
  } else if n <= 0x7FF {
    2
  } else if n <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn XmlBudget::output(self : XmlBudget, ch : Char) -> Unit raise XmlError {
  self.check()
  let bytes = utf8_width(ch)
  if bytes > self.output_bytes {
    self.fail("XML output byte limit exceeded")
  }
  self.output_bytes -= bytes
}

///|
priv struct EntityFrame {
  chars : Array[Char]
  mut pos : Int
  name : String?
}

///|
fn entity_frame(
  value : String,
  name : String?,
  budget : XmlBudget,
) -> EntityFrame raise XmlError {
  // Charge before allocation, including one unit for an empty replacement.
  budget.charge_work(value.length() + 1)
  { chars: value.to_array(), pos: 0, name, }
}

///|
// One builder and explicit frames avoid recursive calls and intermediate copies.
// References and frame visits are paid even when a replacement is empty.
fn decode_xml_value(
  value : String,
  entities : Map[String, DtdEntity],
  budget : XmlBudget,
  attribute_mode? : Bool = false,
) -> String raise XmlError {
  let stack = [entity_frame(value, None, budget)]
  let out = StringBuilder()
  let mut output_chars = 0
  while !stack.is_empty() {
    let frame = stack[stack.length() - 1]
    if frame.pos == frame.chars.length() {
      ignore(stack.pop())
      continue
    }
    let ch = frame.chars[frame.pos]
    frame.pos += 1
    let decoded = if ch != '&' {
      if attribute_mode && (ch == '\t' || ch == '\n' || ch == '\r') {
        ' '
      } else {
        ch
      }
    } else {
      budget.reference()
      let name = StringBuilder()
      while frame.pos < frame.chars.length() && frame.chars[frame.pos] != ';' {
        name.write_char(frame.chars[frame.pos])
        frame.pos += 1
      }
      if frame.pos == frame.chars.length() {
        raise Malformed("unterminated entity")
      }
      frame.pos += 1
      match name.to_string() {
        "amp" => '&'
        "lt" => '<'
        "gt" => '>'
        "quot" => '"'
        "apos" => '\''
        x if x.has_prefix("#") => numeric(x[1:].to_owned())
        name =>
          match entities.get(name) {
            Some(Internal(replacement)) => {
              if stack.any(f => f.name == Some(name)) {
                raise Malformed("recursive general entity")
              }
              if stack.length() - 1 >= budget.limits.depth {
                budget.fail("general entity nesting limit exceeded")
              }
              let next = entity_frame(replacement, Some(name), budget)
              if next.chars.contains('<') {
                raise Malformed(
                  if attribute_mode {
                    "less-than sign in attribute entity replacement"
                  } else {
                    "markup in a general entity is unsupported"
                  },
                )
              }
              stack.push(next)
              continue
            }
            Some(External) =>
              raise Malformed(
                "external general entity expansion is unsupported",
              )
            Some(Unparsed) =>
              raise Malformed("unparsed entity reference is forbidden")
            None => raise Malformed("undeclared general entity")
          }
      }
    }
    if output_chars == 1_048_576 {
      budget.fail("general entity expansion limit exceeded")
    }
    budget.output(decoded)
    out.write_char(decoded)
    output_chars += 1
  }
  out.to_string()
}
