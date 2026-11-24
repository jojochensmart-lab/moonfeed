///|
test "maintenance quoted CR and LF are retained in Atom authors and contributors" {
  for
    (encoded, expected) in [
      ("&quot;a\\&#13;b&quot;@example.org", "\"a\\\rb\"@example.org"),
      ("&quot;a\\&#10;b&quot;@example.org", "\"a\\\nb\"@example.org"),
      ("a(comment\\&#10;)@[domain\\&#13;]", "a(comment\\\n)@[domain\\\r]"),
    ] {
    let feed = feed_document(
      "<feed xmlns='http://www.w3.org/2005/Atom'><id>urn:f</id><title>F</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name><email>" +
      encoded +
      "</email></author><contributor><name>C</name><email>" +
      encoded +
      "</email></contributor></feed>",
    )
    assert_eq(feed.metadata.authors[0].email, Some(expected))
    assert_eq(feed.metadata.contributors[0].email, Some(expected))
  }
}

///|
test "maintenance bare email line breaks and unfinished escapes remain invalid" {
  for
    encoded in [
      "&quot;a&#10;b&quot;@example.org", "&quot;a&#13;b&quot;@example.org", "a&#10;@example.org",
      "a(comment&#10;)@example.org", "a@[domain&#13;]", "&quot;a\\&quot;@example.org",
      "a&#127;@example.org",
    ] {
    assert_true(
      strict_error(
        strict_entry_xml(
          "<contributor><name>C</name><email>" +
          encoded +
          "</email></contributor><content/>",
        ),
      )
      is @atom.InvalidRequiredField("entry.contributor[0].email", _),
    )
  }
  for encoded in ["&quot;a\\&#0;b&quot;@example.org", "a&#1;@example.org"] {
    assert_true(
      strict_error(
        strict_entry_xml(
          "<contributor><name>C</name><email>" +
          encoded +
          "</email></contributor><content/>",
        ),
      )
      is @atom.InvalidXml(_),
    )
  }
}

///|
test "maintenance email folding and escaped punctuation preserve source spelling" {
  let email = "&quot;a\\&quot;b\\\\c&quot;(note&#13;&#10; folded)@example.org"
  let entry = entry_document(
    strict_entry_xml(
      "<contributor><name>C</name><email>" +
      email +
      "</email></contributor><content/>",
    ),
  )
  assert_eq(
    entry.metadata.contributors[0].email,
    Some("\"a\\\"b\\\\c\"(note\r\n folded)@example.org"),
  )
  assert_true(
    strict_error(
      strict_entry_xml(
        "<content type='text/plain; note=&quot;a\\&#10;b&quot;'>Body</content>",
      ),
    )
    is @atom.InvalidRequiredField("entry.content.type", _),
  )
}

///|
test "maintenance registered Atom MIME type parameter is case insensitive" {
  assert_true(
    strict_error(
      strict_entry_xml(
        "<link href='a' type='application/atom+xml;type=ENTRY'/><link href='b' type='APPLICATION/ATOM+XML;TYPE=&quot;entry&quot;'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  let entry = entry_document(
    strict_entry_xml(
      "<link href='a' type='application/atom+xml;type=entry'/><link href='b' type='application/atom+xml;type=feed'/><content/>",
    ),
  )
  assert_eq(entry.metadata.links.length(), 2)
  assert_eq(
    entry.metadata.links[0].media_type,
    Some("application/atom+xml;type=entry"),
  )
}

///|
test "maintenance registered text plain format and delsp are case insensitive" {
  assert_true(
    strict_error(
      strict_entry_xml(
        "<link href='a' type='text/plain;format=Flowed;delsp=YES'/><link href='b' type='TEXT/PLAIN;DELSP=&quot;yes&quot;;FORMAT=flowed'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  let entry = entry_document(
    strict_entry_xml(
      "<link href='a' type='text/plain;format=flowed;delsp=yes'/><link href='b' type='text/plain;format=fixed;delsp=yes'/><content/>",
    ),
  )
  assert_eq(entry.metadata.links.length(), 2)
}

///|
test "maintenance MIME boundary and unknown parameter values stay case sensitive" {
  for
    media in [
      "multipart/mixed;boundary=", "application/example;type=", "application/example;profile=",
    ] {
    let entry = entry_document(
      strict_entry_xml(
        "<link href='a' type='" +
        media +
        "AbC'/><link href='b' type='" +
        media +
        "abc'/><content/>",
      ),
    )
    assert_eq(entry.metadata.links.length(), 2)
  }
}

///|
test "maintenance MIME repeated parameter occurrences are not silently collapsed" {
  assert_true(
    strict_error(
      strict_entry_xml(
        "<link href='a' type='application/example;x=a;x=b'/><link href='b' type='application/example;x=&quot;b&quot;;X=a'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  let entry = entry_document(
    strict_entry_xml(
      "<link href='a' type='application/example;x=a;x=b'/><link href='b' type='application/example;x=a;x=a'/><content/>",
    ),
  )
  assert_eq(entry.metadata.links.length(), 2)
  for
    invalid in [
      "text/plain;=bad", "text/plain;x", "text/plain;x=a;;x=b", "text/plain;x=&quot;unfinished",
    ] {
    assert_true(
      strict_error(
        strict_entry_xml("<link href='a' type='" + invalid + "'/><content/>"),
      )
      is @atom.InvalidRequiredField("entry.link[0].type", _),
    )
  }
}

///|
test "maintenance stable traits retain typed error diagnostics and value equality" {
  let error = @moonfeed.Rss(
    @rss.InvalidRequiredField(
      "channel.item[0].title|description", "at least one must be present",
    ),
  )
  assert_eq(
    @debug.to_string(error),
    "Rss(\n  InvalidRequiredField(\n    \"channel.item[0].title|description\",\n    \"at least one must be present\",\n  ),\n)",
  )
  assert_eq(
    error,
    @moonfeed.Rss(
      @rss.InvalidRequiredField(
        "channel.item[0].title|description", "at least one must be present",
      ),
    ),
  )
  assert_true(error != @moonfeed.Rss(@rss.InvalidXml("malformed")))
  let feed = @moonfeed.parse(
    "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"F\",\"items\":[]}",
  )
  assert_eq(feed, { ..feed, })
  assert_true(feed != { ..feed, title: "Other", })
  assert_eq(@debug.to_string(@moonfeed.FeedFormat::Rss), "Rss")
}

///|
test "maintenance XML declaration entity handling reaches RSS and standalone Atom Entry" {
  let rss = "<!DOCTYPE rss [<!ENTITY heading '&#x6708;Feed'>]><rss version='2.0'><channel><title>&heading;</title><link>https://example.org/</link><description>D</description><item><description><![CDATA[Body]]>&amp;</description></item></channel></rss>"
  let feed = @moonfeed.parse_rss("\u{FEFF}" + rss)
  assert_eq(feed.title, "月Feed")
  assert_eq(feed.items[0].content_html, Some("Body&"))
  assert_eq(@moonfeed.parse("\u{FEFF}" + rss), feed)
  assert_true(
    @moonfeed.detect_format("\u{FEFF}" + rss) is @moonfeed.FeedFormat::Rss,
  )
  assert_true(
    @test.expect_error(() => @moonfeed.parse_rss("\u{FEFF}\u{FEFF}" + rss))
    is @rss.InvalidXml(_),
  )
  assert_true(
    @test.expect_error(() => @moonfeed.parse("\u{FEFF}\u{FEFF}" + rss))
    is @moonfeed.Detect(_),
  )
  let entry = entry_document(
    "\u{FEFF}<!DOCTYPE entry [<!ENTITY heading '&#x6708;Feed'>]><entry xmlns='http://www.w3.org/2005/Atom'><id>urn:e</id><title>&heading;</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author><content>Body</content></entry>",
  )
  assert_eq(entry.metadata.title.unwrap().value, "月Feed")
  assert_eq(entry.metadata.id, Some("urn:e"))
  assert_true(
    strict_error("\u{FEFF}\u{FEFF}" + strict_entry_xml("<content/>"))
    is @atom.InvalidXml(_),
  )
  assert_true(
    @test.expect_error(() => {
      @moonfeed.parse_rss(
        "<!DOCTYPE rss [<!ENTITY unused '\u{0}'>]><rss version='2.0'><channel><title>F</title><link>u</link><description>D</description></channel></rss>",
      )
    })
    is @rss.InvalidXml(_),
  )
}
