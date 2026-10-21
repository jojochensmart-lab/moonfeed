///|
/// Original IRI reference and its RFC 3986 resolved form. Without an absolute
/// XML/document base, a relative result remains relative and is marked explicitly.
pub(all) struct IriReference {
  raw : String
  resolved : String
  is_absolute : Bool
}

///|
priv struct IriParts {
  scheme : String?
  authority : String?
  path : String
  query : String?
  fragment : String?
}

///|
fn chars_span(chars : Array[Char], start : Int, end : Int) -> String {
  let out = StringBuilder()
  for i = start; i < end; i = i + 1 {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn hex_digit(c : Char) -> Bool {
  ascii_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn iri_authority(value : String) -> Unit raise ParseError {
  let a = value.to_array()
  let mut start = 0
  let mut at_seen = false
  for i, c in a {
    if c == '@' {
      if at_seen {
        raise InvalidRequiredField(
          "iri", "multiple authority userinfo separators",
        )
      }
      at_seen = true
      start = i + 1
    }
  }
  for i = 0; i < start; i = i + 1 {
    if a[i] == '[' || a[i] == ']' {
      raise InvalidRequiredField("iri", "invalid userinfo character")
    }
  }
  let mut port_start = a.length()
  if start < a.length() && a[start] == '[' {
    let mut end = start + 1
    while end < a.length() && a[end] != ']' {
      end += 1
    }
    if end == a.length() {
      raise InvalidRequiredField("iri", "unclosed IP literal")
    }
    let literal = chars_span(a, start + 1, end)
    if !literal.contains(":") &&
      !literal.has_prefix("v") &&
      !literal.has_prefix("V") {
      raise InvalidRequiredField("iri", "invalid IP literal")
    }
    if end + 1 < a.length() {
      if a[end + 1] != ':' {
        raise InvalidRequiredField("iri", "invalid data after IP literal")
      }
      port_start = end + 2
    }
  } else {
    let mut colon_seen = false
    for i = start; i < a.length(); i = i + 1 {
      if a[i] == '[' || a[i] == ']' {
        raise InvalidRequiredField("iri", "invalid host brackets")
      }
      if a[i] == ':' {
        if colon_seen {
          raise InvalidRequiredField("iri", "IPv6 host must be bracketed")
        }
        colon_seen = true
        port_start = i + 1
      }
    }
  }
  for i = port_start; i < a.length(); i = i + 1 {
    if !ascii_digit(a[i]) {
      raise InvalidRequiredField("iri", "port must be decimal digits")
    }
  }
}

///|
fn iri_parts(input : String) -> IriParts raise ParseError {
  parse_iri_parts(input, false)
}

///|
fn parse_iri_parts(
  input : String,
  legacy_base : Bool,
) -> IriParts raise ParseError {
  let a = input.to_array()
  for i, c in a {
    if (
        !legacy_base &&
        (
          c.to_int() <= 0x20 ||
          (c.to_int() >= 0x80 && c.to_int() <= 0x9F) ||
          c.to_int() == 0x7F ||
          c == '<' ||
          c == '>' ||
          c == '"' ||
          c == '\\' ||
          c == '^' ||
          c == '`' ||
          c == '{' ||
          c == '|' ||
          c == '}'
        )
      ) ||
      c.to_int() < 0x20 {
      raise InvalidRequiredField("iri", "invalid IRI character")
    }
    if c == '%' &&
      (i + 2 >= a.length() || !hex_digit(a[i + 1]) || !hex_digit(a[i + 2])) {
      raise InvalidRequiredField("iri", "invalid percent escape")
    }
  }
  let mut fragment_at = a.length()
  for i, c in a {
    if c == '#' {
      if fragment_at != a.length() {
        raise InvalidRequiredField("iri", "multiple fragment delimiters")
      }
      fragment_at = i
    }
  }
  let fragment = if fragment_at < a.length() {
    Some(chars_span(a, fragment_at + 1, a.length()))
  } else {
    None
  }
  let mut query_at = fragment_at
  for i = 0; i < fragment_at; i = i + 1 {
    if a[i] == '?' {
      query_at = i
      break
    }
  }
  let query = if query_at < fragment_at {
    Some(chars_span(a, query_at + 1, fragment_at))
  } else {
    None
  }
  let mut scheme = None
  let mut start = 0
  for i = 0; i < query_at; i = i + 1 {
    if a[i] == '/' {
      break
    }
    if a[i] == ':' {
      if i == 0 || !ascii_alpha(a[0]) {
        raise InvalidRequiredField("iri", "invalid scheme")
      }
      for j = 1; j < i; j = j + 1 {
        if !ascii_alpha(a[j]) &&
          !ascii_digit(a[j]) &&
          a[j] != '+' &&
          a[j] != '-' &&
          a[j] != '.' {
          raise InvalidRequiredField("iri", "invalid scheme")
        }
      }
      scheme = Some(chars_span(a, 0, i))
      start = i + 1
      break
    }
  }
  let mut authority = None
  if start + 1 < query_at && a[start] == '/' && a[start + 1] == '/' {
    let auth_start = start + 2
    start = auth_start
    while start < query_at && a[start] != '/' {
      start += 1
    }
    let auth = chars_span(a, auth_start, start)
    let mut brackets = 0
    for c in auth.to_array() {
      if c == '[' {
        brackets += 1
      }
      if c == ']' {
        brackets -= 1
      }
      if brackets < 0 || brackets > 1 {
        raise InvalidRequiredField("iri", "invalid authority brackets")
      }
    }
    if brackets != 0 {
      raise InvalidRequiredField("iri", "unclosed authority bracket")
    }
    authority = Some(auth)
    iri_authority(auth)
  }
  let path = chars_span(a, start, query_at)
  for component in [Some(path), query, fragment] {
    if component is Some(s) && (s.contains("[") || s.contains("]")) {
      raise InvalidRequiredField(
        "iri", "brackets are only allowed in authority IP literals",
      )
    }
  }
  { scheme, authority, path, query, fragment, }
}

///|
fn drop_last_segment(path : String) -> String {
  let a = path.to_array()
  let mut last = -1
  for i, c in a {
    if c == '/' {
      last = i
    }
  }
  if last < 0 {
    ""
  } else {
    chars_span(a, 0, last)
  }
}

///|
/// RFC 3986 section 5.2.4, preserving empty segments and percent-encoded dots.
fn remove_dot_segments(path : String) -> String {
  let mut input = path
  let mut output = ""
  while !input.is_empty() {
    if input.has_prefix("../") {
      input = input[3:].to_owned()
    } else if input.has_prefix("./") {
      input = input[2:].to_owned()
    } else if input.has_prefix("/./") {
      input = input[2:].to_owned()
    } else if input == "/." {
      input = "/"
    } else if input.has_prefix("/../") {
      input = input[3:].to_owned()
      output = drop_last_segment(output)
    } else if input == "/.." {
      input = "/"
      output = drop_last_segment(output)
    } else if input == "." || input == ".." {
      input = ""
    } else {
      let a = input.to_array()
      let mut end = if a[0] == '/' { 1 } else { 0 }
      while end < a.length() && a[end] != '/' {
        end += 1
      }
      output = output + chars_span(a, 0, end)
      input = chars_span(a, end, a.length())
    }
  }
  output
}

///|
fn recompose(parts : IriParts) -> String {
  let out = StringBuilder()
  if parts.scheme is Some(s) {
    out.write_string(s + ":")
  }
  if parts.authority is Some(a) {
    out.write_string("//" + a)
  }
  out.write_string(parts.path)
  if parts.query is Some(q) {
    out.write_string("?" + q)
  }
  if parts.fragment is Some(f) {
    out.write_string("#" + f)
  }
  out.to_string()
}

///|
/// Until a retrieval/absolute base is known, leading parent segments must survive.
fn unresolved_dot_segments(path : String) -> String {
  let segments = path.split("/").to_array()
  let output : Array[String] = []
  for i, segment in segments {
    if segment == "." {
      continue
    }
    if segment == ".." {
      if !output.is_empty() && output[output.length() - 1] != ".." {
        let _ = output.pop()
      } else {
        output.push("..")
      }
    } else if i != segments.length() - 1 || !segment.is_empty() {
      output.push(segment.to_owned())
    }
  }
  let result = output.join("/")
  if !result.is_empty() &&
    (
      path.has_suffix("/") ||
      path.has_suffix("/.") ||
      path.has_suffix("/..") ||
      path == ".."
    ) {
    result + "/"
  } else {
    result
  }
}

///|
/// Resolve by component parsing, path merging and dot-segment removal (RFC 3986 §5).
pub fn resolve_reference(
  base : String?,
  reference : String,
) -> IriReference raise ParseError {
  resolve_iri(base, reference, false)
}

///|
fn resolve_xml_base(
  base : String?,
  reference : String,
) -> IriReference raise ParseError {
  resolve_iri(base, reference, true)
}

///|
fn resolve_iri(
  base : String?,
  reference : String,
  legacy_base : Bool,
) -> IriReference raise ParseError {
  let r = parse_iri_parts(reference, legacy_base)
  let target = if r.scheme is Some(_) {
    { ..r, path: remove_dot_segments(r.path), }
  } else if base is Some(value) {
    let b = parse_iri_parts(value, true)
    if r.authority is Some(_) {
      { ..r, scheme: b.scheme, path: remove_dot_segments(r.path), }
    } else if r.path.is_empty() {
      {
        ..r,
        scheme: b.scheme,
        authority: b.authority,
        path: b.path,
        query: if r.query is Some(_) {
          r.query
        } else {
          b.query
        },
      }
    } else {
      let merged = if r.path.has_prefix("/") {
        r.path
      } else if b.authority is Some(_) && b.path.is_empty() {
        "/" + r.path
      } else {
        let a = b.path.to_array()
        let mut last = -1
        for i, c in a {
          if c == '/' {
            last = i
          }
        }
        chars_span(a, 0, last + 1) + r.path
      }
      {
        ..r,
        scheme: b.scheme,
        authority: b.authority,
        path: if b.scheme is None &&
          b.authority is None &&
          !merged.has_prefix("/") {
          unresolved_dot_segments(merged)
        } else {
          remove_dot_segments(merged)
        },
      }
    }
  } else if legacy_base && !r.path.has_prefix("/") {
    { ..r, path: unresolved_dot_segments(r.path), }
  } else {
    r
  }
  {
    raw: reference,
    resolved: recompose(target),
    is_absolute: target.scheme is Some(_),
  }
}
