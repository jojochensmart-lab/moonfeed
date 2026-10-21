///|
/// Reject invalid URI characters without case folding or percent decoding.
/// Relative namespace names remain accepted (deprecated, not prohibited).
fn namespace_reference(value : String) -> Unit raise XmlError {
  let a = value.to_array()
  let mut fragments = 0
  for i, c in a {
    if c.to_int() <= 0x20 ||
      c.to_int() >= 0x7F ||
      "<>\"\\^`{|}".contains(c.to_string()) {
      raise Malformed("namespace: invalid URI-reference character")
    }
    if c == '#' {
      fragments += 1
    }
    if c == '%' &&
      (
        i + 2 >= a.length() ||
        digit(a[i + 1]) is None ||
        digit(a[i + 2]) is None
      ) {
      raise Malformed("namespace: invalid URI percent escape")
    }
  }
  if fragments > 1 {
    raise Malformed("namespace: multiple fragment delimiters")
  }
}
