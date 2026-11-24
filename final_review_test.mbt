///|
test "final review unknown MIME charset values keep their original semantics" {
  for
    media in [
      "application/x-private", "text/x-private", "application/vnd.example+xml",
    ] {
    let entry = entry_document(
      strict_entry_xml(
        "<link href='a' type='" +
        media +
        ";charset=AbC'/><link href='b' type='" +
        media +
        ";CHARSET=abc'/><content/>",
      ),
    )
    assert_eq(entry.metadata.links.length(), 2)
    assert_eq(entry.metadata.links[0].media_type, Some(media + ";charset=AbC"))
    assert_eq(entry.metadata.links[1].media_type, Some(media + ";CHARSET=abc"))
  }
}

///|
test "final review verified charset registrations remain case insensitive" {
  for
    media in [
      "text/plain", "text/html", "text/xml", "application/xml", "application/atom+xml",
      "application/xhtml+xml",
    ] {
    assert_true(
      strict_error(
        strict_entry_xml(
          "<link href='a' type='" +
          media +
          ";charset=UTF-8;profile=Keep'/><link href='b' type='" +
          media +
          ";PROFILE=Keep;CHARSET=&quot;utf-8&quot;'/><content/>",
        ),
      )
      is @atom.InvalidRequiredField("entry.link[1]", _),
    )
  }
}
