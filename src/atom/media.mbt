///|
priv struct MediaType {
  essence : String
  parameters : Array[(String, String)]
}

///|
fn token_char(c : Char) -> Bool {
  c.to_int() > 0x20 &&
  c.to_int() < 0x7F &&
  !"()<>@,;:\\\"/[]?=".contains(c.to_string())
}

///|
fn header_characters(a : Array[Char], path : String) -> Unit raise ParseError {
  for i, c in a {
    if c.to_int() > 0x7E ||
      (c.to_int() < 0x20 && c != '\t' && c != '\r' && c != '\n') {
      raise InvalidRequiredField(path, "invalid header character")
    }
    if c == '\r' &&
      (
        i + 2 >= a.length() ||
        a[i + 1] != '\n' ||
        (a[i + 2] != ' ' && a[i + 2] != '\t')
      ) {
      raise InvalidRequiredField(path, "invalid folding whitespace")
    }
    if c == '\n' && (i == 0 || a[i - 1] != '\r') {
      raise InvalidRequiredField(path, "bare newline in header value")
    }
  }
}

///|
fn mime_token(
  a : Array[Char],
  start : Int,
  path : String,
) -> (String, Int) raise ParseError {
  let begin = mail_cfws(a, start, path)
  let mut end = begin
  while end < a.length() && token_char(a[end]) {
    end += 1
  }
  if end == begin {
    raise InvalidRequiredField(path, "missing MIME token")
  }
  (chars_span(a, begin, end), mail_cfws(a, end, path))
}

///|
fn parse_media_type(
  value : String,
  path : String,
) -> MediaType raise ParseError {
  let a = value.to_array()
  header_characters(a, path)
  let (major, slash) = mime_token(a, 0, path)
  if slash >= a.length() || a[slash] != '/' {
    raise InvalidRequiredField(path, "expected MIME type/subtype")
  }
  let (minor, after) = mime_token(a, slash + 1, path)
  let essence = major.to_lower() + "/" + minor.to_lower()
  let mut pos = after
  let parameters : Array[(String, String)] = []
  while pos < a.length() {
    if a[pos] != ';' {
      raise InvalidRequiredField(path, "expected MIME parameter separator")
    }
    let (name, equal) = mime_token(a, pos + 1, path)
    if equal >= a.length() || a[equal] != '=' {
      raise InvalidRequiredField(path, "expected MIME parameter value")
    }
    pos = mail_cfws(a, equal + 1, path)
    let parameter = if pos < a.length() && a[pos] == '"' {
      pos += 1
      let out = StringBuilder()
      let mut closed = false
      while pos < a.length() {
        if a[pos] == '"' {
          pos += 1
          closed = true
          break
        }
        if a[pos] == '\\' {
          pos += 1
          if pos >= a.length() {
            raise InvalidRequiredField(path, "unfinished MIME escape")
          }
          out.write_char(a[pos])
        } else if a[pos] != '\r' && a[pos] != '\n' {
          out.write_char(a[pos])
        }
        pos += 1
      }
      if !closed {
        raise InvalidRequiredField(path, "unclosed MIME quoted value")
      }
      pos = mail_cfws(a, pos, path)
      out.to_string()
    } else {
      let (token, next) = mime_token(a, pos, path)
      pos = next
      token
    }
    let key = name.to_lower()
    // RFC 2045 makes parameter names case-insensitive and values case-sensitive
    // unless their governing media-type registration says otherwise. Apply the
    // explicit charset and RFC 2046 external-body exceptions here.
    let case_insensitive_value = key == "charset" ||
      (
        essence == "message/external-body" &&
        (key == "access-type" || key == "permission" || key == "mode")
      )
    parameters.push(
      (
        key,
        if case_insensitive_value {
          parameter.to_lower()
        } else {
          parameter
        },
      ),
    )
  }
  { essence, parameters, }
}

///|
fn same_media_type(
  left : String?,
  right : String?,
  path : String,
) -> Bool raise ParseError {
  match (left, right) {
    (None, None) => true
    (Some(l), Some(r)) => {
      let a = parse_media_type(l, path)
      let b = parse_media_type(r, path)
      if a.essence != b.essence ||
        a.parameters.length() != b.parameters.length() {
        return false
      }
      // Multiset comparison preserves even repeated parameter occurrences.
      let matched = b.parameters.map(_ => false)
      for parameter in a.parameters {
        let mut found = false
        for i, candidate in b.parameters {
          if !matched[i] && candidate == parameter {
            matched[i] = true
            found = true
            break
          }
        }
        if !found {
          return false
        }
      }
      true
    }
    _ => false
  }
}
