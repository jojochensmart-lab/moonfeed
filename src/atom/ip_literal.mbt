///|
fn ip_literal(value : String) -> Bool {
  @xmlmini.is_valid_ip_literal(value)
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
