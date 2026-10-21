///|
fn ipv4(value : String) -> Bool {
  let parts = value.split(".").to_array()
  if parts.length() != 4 {
    return false
  }
  for part in parts {
    let a = part.to_owned().to_array()
    if a.is_empty() ||
      a.length() > 3 ||
      !a.all(ascii_digit) ||
      (a.length() > 1 && a[0] == '0') {
      return false
    }
    let mut n = 0
    for c in a {
      n = n * 10 + c.to_int() - 48
    }
    if n > 255 {
      return false
    }
  }
  true
}

///|
fn ip_literal(value : String) -> Bool {
  let a = value.to_array()
  if a.length() > 2 && (a[0] == 'v' || a[0] == 'V') {
    let mut pos = 1
    while pos < a.length() && hex_digit(a[pos]) {
      pos += 1
    }
    if pos == 1 || pos + 1 >= a.length() || a[pos] != '.' {
      return false
    }
    for i = pos + 1; i < a.length(); i = i + 1 {
      if !ascii_alpha(a[i]) &&
        !ascii_digit(a[i]) &&
        !"-._~!$&'()*+,;=:".contains(a[i].to_string()) {
        return false
      }
    }
    return true
  }
  let compressed = value.contains("::")
  if (value.has_prefix(":") && !value.has_prefix("::")) ||
    (value.has_suffix(":") && !value.has_suffix("::")) {
    return false
  }
  let halves = value.split("::").to_array()
  if halves.length() > 2 || value.contains(":::") {
    return false
  }
  let mut groups = 0
  let pieces = value.split(":").to_array()
  for i, piece in pieces {
    if piece.is_empty() {
      if !compressed {
        return false
      }
      continue
    }
    let text = piece.to_owned()
    if text.contains(".") {
      if i != pieces.length() - 1 || !ipv4(text) {
        return false
      }
      groups += 2
    } else {
      let chars = text.to_array()
      if chars.length() > 4 || !chars.all(hex_digit) {
        return false
      }
      groups += 1
    }
  }
  if compressed {
    groups < 8
  } else {
    groups == 8
  }
}

///|
/// RFC 3987 ucschar excludes private use, surrogates and plane-end noncharacters.
fn iri_unicode(c : Char, query : Bool) -> Bool {
  let n = c.to_int()
  (n >= 0xA0 && n <= 0xD7FF) ||
  (n >= 0xF900 && n <= 0xFDCF) ||
  (n >= 0xFDF0 && n <= 0xFFEF) ||
  (n >= 0x10000 && n <= 0xDFFFD && n % 65536 <= 0xFFFD) ||
  (n >= 0xE1000 && n <= 0xEFFFD) ||
  (
    query &&
    (
      (n >= 0xE000 && n <= 0xF8FF) ||
      (n >= 0xF0000 && n <= 0xFFFFD) ||
      (n >= 0x100000 && n <= 0x10FFFD)
    )
  )
}
