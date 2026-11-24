///|
test "security repair related MIME equivalence uses nested type not opaque spelling" {
  assert_true(
    strict_error(
      strict_entry_xml(
        "<link href='a' type='Multipart/Related;boundary=AbC;type=&quot;Text/HTML&quot;;start-info=KeepCase'/><link href='b' type='multipart/related;START-INFO=KeepCase;TYPE=&quot;text/html&quot;;BOUNDARY=AbC'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  for
    second in [
      "multipart/related;boundary=abc;type=&quot;text/html&quot;;start-info=KeepCase",
      "multipart/related;boundary=AbC;type=&quot;text/plain&quot;;start-info=KeepCase",
      "multipart/related;boundary=AbC;type=&quot;text/html&quot;;start-info=keepcase",
    ] {
    let entry = entry_document(
      strict_entry_xml(
        "<link href='a' type='multipart/related;boundary=AbC;type=&quot;text/html&quot;;start-info=KeepCase'/><link href='b' type='" +
        second +
        "'/><content/>",
      ),
    )
    assert_eq(entry.metadata.links.length(), 2)
  }
}

///|
test "security repair related MIME rejects malformed nested types and required parameters" {
  for
    media in [
      "multipart/related;boundary=b;type=&quot;text&quot;", "multipart/related;boundary=b;type=&quot;text/html;evil=x&quot;",
      "multipart/related;boundary=b;type=&quot;text/html/extra&quot;", "multipart/related;boundary=b;type=&quot;text/🌓&quot;",
      "multipart/related;boundary=b", "multipart/related;type=&quot;text/html&quot;",
      "multipart/related;boundary=&quot;&quot;;type=&quot;text/html&quot;", "multipart/related;boundary=&quot;b &quot;;type=&quot;text/html&quot;",
    ] {
    assert_true(
      strict_error(
        strict_entry_xml("<link href='a' type='" + media + "'/><content/>"),
      )
      is @atom.InvalidRequiredField("entry.link[0].type", _),
    )
  }
}

///|
test "security repair related MIME does not silently collapse known duplicate parameters" {
  for
    parameter in [
      "type=&quot;text/html&quot;", "boundary=b", "start-info=Info", "start=&quot;&lt;root@example.org&gt;&quot;",
    ] {
    assert_true(
      strict_error(
        strict_entry_xml(
          "<link href='a' type='multipart/related;boundary=b;type=&quot;text/html&quot;;start-info=Info;start=&quot;&lt;root@example.org&gt;&quot;;" +
          parameter +
          "'/><content/>",
        ),
      )
      is @atom.InvalidRequiredField("entry.link[0].type", _),
    )
  }
  let entry = entry_document(
    strict_entry_xml(
      "<link href='a' type='multipart/related;boundary=b;type=&quot;text/html&quot;;x=a;x=b'/><content/>",
    ),
  )
  assert_eq(
    entry.metadata.links[0].media_type,
    Some("multipart/related;boundary=b;type=\"text/html\";x=a;x=b"),
  )
}

///|
test "security repair related MIME does not change unknown type parameter semantics" {
  let entry = entry_document(
    strict_entry_xml(
      "<link href='a' type='application/x-example;type=&quot;Text/HTML&quot;'/><link href='b' type='application/x-example;type=&quot;text/html&quot;'/><content/>",
    ),
  )
  assert_eq(entry.metadata.links.length(), 2)
}

///|
test "security repair shared entity rules reach RSS Atom Feed and Entry" {
  let rss = @moonfeed.parse_rss(
    "<!DOCTYPE rss [<!ENTITY h 'Safe'>]><rss version='2.0'><channel><title>&h;</title><link>u</link><description>D</description><item><description>&h;</description></item></channel></rss>",
  )
  assert_eq(rss.title, "Safe")
  assert_eq(rss.items[0].content_html, Some("Safe"))
  let feed = feed_document(
    "<!DOCTYPE feed [<!ENTITY h 'Safe'>]>" +
    strict_feed_xml("<subtitle>&h;</subtitle>"),
  )
  assert_eq(feed.metadata.subtitle.unwrap().value, "Safe")
  let entry = entry_document(
    "<!DOCTYPE entry [<!ENTITY h 'Safe'>]>" +
    strict_entry_xml("<content>&h;</content>"),
  )
  assert_eq(entry.content.unwrap().value, "Safe")
  for
    subset in [
      "<!ENTITY % p SYSTEM 'urn:p' NDATA n>", "<!ATTLIST absent a CDATA '&missing;'>",
      "<!ATTLIST entry a CDATA '&later;'><!ENTITY later 'v'>",
    ] {
    assert_true(
      strict_error(
        "<!DOCTYPE entry [" + subset + "]>" + strict_entry_xml("<content/>"),
      )
      is @atom.InvalidXml(_),
    )
  }
}

///|
test "security repair public API bounds empty amplification before output grows" {
  let mut subset = "<!ENTITY e0 ''>"
  for i = 1; i <= 20; i = i + 1 {
    let reference = "&e" + (i - 1).to_string() + ";"
    subset += "<!ENTITY e" + i.to_string() + " '" + reference + reference + "'>"
  }
  let xml = "<!DOCTYPE entry [" +
    subset +
    "]>" +
    strict_entry_xml("<content>&e20;</content>")
  assert_true(
    strict_error(xml) is @atom.InvalidXml("XML entity reference limit exceeded"),
  )
}
