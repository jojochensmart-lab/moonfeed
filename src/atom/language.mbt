///|
/// RFC 3066 section 2.1 syntax, as referenced by Atom/XML 1.0 fourth edition.
/// This checks syntax, not assignments in a changing language registry.
fn validate_language(
  value : String,
  path : String,
  allow_empty : Bool,
) -> Unit raise ParseError {
  if allow_empty && value.is_empty() {
    return
  }
  for i, part in value.split("-").to_array() {
    let chars = part.to_owned().to_array()
    if chars.is_empty() ||
      chars.length() > 8 ||
      !chars.all(c => ascii_alpha(c) || (i > 0 && ascii_digit(c))) {
      raise InvalidRequiredField(path, "expected RFC 3066 language-tag syntax")
    }
  }
}

///|
fn validate_document_languages(node : Node) -> Unit raise ParseError {
  for a in node.attributes {
    if a.name.namespace_uri == Some("http://www.w3.org/XML/1998/namespace") &&
      a.name.local_name == "lang" {
      validate_language(a.value, "xml:lang", true)
    }
  }
  for child in node.children {
    validate_document_languages(child)
  }
}
