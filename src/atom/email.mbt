///|
fn mail_cfws(
  a : Array[Char],
  start : Int,
  path : String,
) -> Int raise ParseError {
  let mut pos = start
  while pos < a.length() {
    if a[pos] == ' ' || a[pos] == '\t' || a[pos] == '\r' || a[pos] == '\n' {
      pos += 1
      continue
    }
    if a[pos] != '(' {
      break
    }
    let mut depth = 1
    pos += 1
    while pos < a.length() && depth > 0 {
      if a[pos] == '\\' {
        pos += 1
        if pos >= a.length() {
          raise InvalidRequiredField(path, "unfinished email comment escape")
        }
      } else if a[pos] == '(' {
        depth += 1
      } else if a[pos] == ')' {
        depth -= 1
      }
      if depth > 32 {
        raise InvalidRequiredField(path, "email comment nesting exceeds 32")
      }
      pos += 1
    }
    if depth != 0 {
      raise InvalidRequiredField(path, "unclosed email comment")
    }
  }
  pos
}

///|
fn mail_atom(c : Char) -> Bool {
  ascii_alpha(c) ||
  ascii_digit(c) ||
  "!#$%&'*+-/=?^_`{|}~".contains(c.to_string())
}

///|
fn mail_word(
  a : Array[Char],
  start : Int,
  quoted : Bool,
  path : String,
) -> Int raise ParseError {
  let mut pos = mail_cfws(a, start, path)
  if quoted && pos < a.length() && a[pos] == '"' {
    pos += 1
    while pos < a.length() {
      if a[pos] == '"' {
        return mail_cfws(a, pos + 1, path)
      }
      if a[pos] == '\\' {
        pos += 1
        if pos >= a.length() {
          raise InvalidRequiredField(path, "unfinished quoted email escape")
        }
      }
      pos += 1
    }
    raise InvalidRequiredField(path, "unclosed quoted email local part")
  }
  let begin = pos
  while pos < a.length() && mail_atom(a[pos]) {
    pos += 1
  }
  if pos == begin {
    raise InvalidRequiredField(path, "missing email atom")
  }
  mail_cfws(a, pos, path)
}

///|
/// Addr-spec parser with dot atoms, quoted words, comments and domain literals.
/// Obsolete control-character/FWS productions remain outside the validated subset.
fn validate_email(value : String, path : String) -> Unit raise ParseError {
  let a = value.to_array()
  header_characters(a, path)
  for c in a {
    if c.to_int() > 0x7F ||
      (c.to_int() < 0x20 && c != '\t' && c != '\r' && c != '\n') {
      raise InvalidRequiredField(
        path, "email must use RFC 2822 ASCII addr-spec",
      )
    }
  }
  let mut pos = mail_word(a, 0, true, path)
  while pos < a.length() && a[pos] == '.' {
    pos = mail_word(a, pos + 1, true, path)
  }
  if pos >= a.length() || a[pos] != '@' {
    raise InvalidRequiredField(path, "email requires one @ separator")
  }
  pos = mail_cfws(a, pos + 1, path)
  if pos < a.length() && a[pos] == '[' {
    pos += 1
    let mut closed = false
    while pos < a.length() {
      if a[pos] == ']' {
        pos += 1
        closed = true
        break
      }
      if a[pos] == '[' {
        raise InvalidRequiredField(path, "nested email domain literal")
      }
      if a[pos] == '\\' {
        pos += 1
      }
      if pos >= a.length() {
        raise InvalidRequiredField(path, "unfinished email domain literal")
      }
      pos += 1
    }
    if !closed {
      raise InvalidRequiredField(path, "unclosed email domain literal")
    }
    pos = mail_cfws(a, pos, path)
  } else {
    pos = mail_word(a, pos, false, path)
    while pos < a.length() && a[pos] == '.' {
      pos = mail_word(a, pos + 1, false, path)
    }
  }
  if pos != a.length() {
    raise InvalidRequiredField(path, "unexpected data after email addr-spec")
  }
}
