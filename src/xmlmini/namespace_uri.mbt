///|
fn uri_alpha(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn uri_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn uri_unreserved(c : Char) -> Bool {
  uri_alpha(c) || uri_digit(c) || "-._~".contains(c.to_string())
}

///|
fn uri_sub_delim(c : Char) -> Bool {
  "!$&'()*+,;=".contains(c.to_string())
}

///|
fn uri_component_char(c : Char) -> Bool {
  uri_unreserved(c) ||
  uri_sub_delim(c) ||
  c == '%' ||
  c == ':' ||
  c == '@' ||
  c == '/' ||
  c == '?'
}

///|
fn valid_scheme(a : Array[Char], start : Int, end : Int) -> Bool {
  if start >= end || !uri_alpha(a[start]) {
    return false
  }
  for i = start + 1; i < end; i = i + 1 {
    let c = a[i]
    if !uri_alpha(c) && !uri_digit(c) && c != '+' && c != '-' && c != '.' {
      return false
    }
  }
  true
}

///|
fn valid_reg_name(a : Array[Char], start : Int, end : Int) -> Bool {
  let mut i = start
  while i < end {
    if uri_unreserved(a[i]) || uri_sub_delim(a[i]) {
      i += 1
    } else if a[i] == '%' {
      if i + 2 >= end || digit(a[i + 1]) is None || digit(a[i + 2]) is None {
        return false
      }
      i += 3
    } else {
      return false
    }
  }
  true
}

///|
fn valid_authority(a : Array[Char], start : Int, end : Int) -> Bool {
  let mut at = -1
  for i = start; i < end; i = i + 1 {
    if a[i] == '@' {
      if at >= 0 {
        return false
      }
      at = i
    }
  }
  let host_start = if at >= 0 { at + 1 } else { start }
  if at >= 0 && !valid_reg_name(a, start, at) {
    // Userinfo additionally permits colons.
    let mut i = start
    while i < at {
      if uri_unreserved(a[i]) || uri_sub_delim(a[i]) || a[i] == ':' {
        i += 1
      } else if a[i] == '%' &&
        i + 2 < at &&
        digit(a[i + 1]) is Some(_) &&
        digit(a[i + 2]) is Some(_) {
        i += 3
      } else {
        return false
      }
    }
  }
  if host_start >= end {
    return true
  }
  if a[host_start] == '[' {
    let mut close = -1
    for i = host_start + 1; i < end; i = i + 1 {
      if a[i] == '[' {
        return false
      }
      if a[i] == ']' {
        close = i
        break
      }
    }
    if close < 0 {
      return false
    }
    let literal = StringBuilder()
    for i = host_start + 1; i < close; i = i + 1 {
      literal.write_char(a[i])
    }
    if !is_valid_ip_literal(literal.to_string()) {
      return false
    }
    if close + 1 == end {
      return true
    }
    if a[close + 1] != ':' {
      return false
    }
    for i = close + 2; i < end; i = i + 1 {
      if !uri_digit(a[i]) {
        return false
      }
    }
    true
  } else {
    let mut colon = -1
    for i = host_start; i < end; i = i + 1 {
      if a[i] == ':' {
        if colon >= 0 {
          return false
        }
        colon = i
      }
    }
    let host_end = if colon >= 0 { colon } else { end }
    if !valid_reg_name(a, host_start, host_end) {
      return false
    }
    if colon >= 0 {
      for i = colon + 1; i < end; i = i + 1 {
        if !uri_digit(a[i]) {
          return false
        }
      }
    }
    true
  }
}

///|
/// Check the RFC 3986 URI-reference structure without normalizing its spelling.
/// Relative namespace names remain accepted as required by Namespaces in XML.
fn namespace_reference(value : String) -> Unit raise XmlError {
  let a = value.to_array()
  let mut fragment = a.length()
  for i, c in a {
    if c.to_int() <= 0x20 ||
      c.to_int() >= 0x7F ||
      "<>\\^`{|}".contains(c.to_string()) {
      raise Malformed("namespace: invalid URI-reference character")
    }
    if c == '#' {
      if fragment != a.length() {
        raise Malformed("namespace: multiple fragment delimiters")
      }
      fragment = i
    }
    if c == '%' &&
      (
        i + 2 >= a.length() ||
        digit(a[i + 1]) is None ||
        digit(a[i + 2]) is None
      ) {
      raise Malformed("namespace: invalid URI percent escape")
    }
    if c == '[' || c == ']' {
      // Brackets are valid only in an authority IP-literal host.
      continue
    }
  }
  let mut query = fragment
  for i = 0; i < fragment; i = i + 1 {
    if a[i] == '?' {
      query = i
      break
    }
  }
  for i = 0; i < query; i = i + 1 {
    let c = a[i]
    if !uri_component_char(c) && c != '[' && c != ']' {
      raise Malformed("namespace: invalid URI path character")
    }
  }
  for i = query; i < fragment; i = i + 1 {
    let c = a[i]
    if c == '[' || c == ']' || !uri_component_char(c) {
      raise Malformed("namespace: invalid URI query character")
    }
  }
  for i = fragment + 1; i < a.length(); i = i + 1 {
    let c = a[i]
    if c == '[' || c == ']' || (c != '#' && !uri_component_char(c)) {
      raise Malformed("namespace: invalid URI fragment character")
    }
  }
  let mut colon = -1
  let mut slash = query
  for i = 0; i < query; i = i + 1 {
    if a[i] == ':' && colon < 0 {
      colon = i
    }
    if a[i] == '/' && slash == query {
      slash = i
    }
  }
  let has_scheme = colon >= 0 && colon < slash
  let path_start = if has_scheme { colon + 1 } else { 0 }
  if has_scheme && !valid_scheme(a, 0, colon) {
    raise Malformed("namespace: invalid URI scheme")
  }
  if !has_scheme && colon >= 0 && colon < slash {
    raise Malformed("namespace: colon in first relative path segment")
  }
  let authority_start = path_start + 2
  let has_authority = path_start + 1 < query &&
    a[path_start] == '/' &&
    a[path_start + 1] == '/'
  if has_authority {
    let mut authority_end = query
    for i = authority_start; i < query; i = i + 1 {
      if a[i] == '/' {
        authority_end = i
        break
      }
    }
    if !valid_authority(a, authority_start, authority_end) {
      raise Malformed("namespace: invalid URI authority")
    }
    for i = authority_end; i < query; i = i + 1 {
      if a[i] == '[' || a[i] == ']' {
        raise Malformed("namespace: bracket outside IP-literal host")
      }
    }
  } else {
    for i = path_start; i < query; i = i + 1 {
      if a[i] == '[' || a[i] == ']' {
        raise Malformed("namespace: bracket outside IP-literal host")
      }
    }
  }
}
