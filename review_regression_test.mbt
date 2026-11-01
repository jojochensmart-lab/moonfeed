///|
test "review JSON attachments preserve ordered metadata and integer precision" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Audio","items":[{"id":"a","content_text":"Episode","attachments":[{"url":"https://example.org/a.mp3","mime_type":"audio/mpeg","title":"Audio","size_in_bytes":18446744073709551615,"duration_in_seconds":2.5},{"url":"https://example.org/a.ogg","mime_type":"audio/ogg","size_in_bytes":1e3}]}]}
  let direct : @moonfeed.Feed = @moonfeed.parse_json_feed(input)
  let automatic = @moonfeed.parse(input)
  assert_eq(direct, automatic)
  let files : Array[@moonfeed.Attachment] = direct.items[0].attachments
  assert_eq(files.length(), 2)
  assert_eq(files[0].url, "https://example.org/a.mp3")
  assert_eq(files[0].mime_type, "audio/mpeg")
  assert_eq(files[0].title, Some("Audio"))
  assert_eq(files[0].size_in_bytes, Some(18446744073709551615UL))
  assert_eq(files[0].duration_in_seconds, Some(2.5))
  assert_eq(files[1].size_in_bytes, Some(1000UL))
  assert_eq(files[1].duration_in_seconds, None)
}

///|
test "review JSON attachment numeric boundaries and optional fields" {
  let prefix = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"F\",\"items\":[{\"id\":\"a\",\"content_text\":\"x\",\"attachments\":[{\"url\":\"u\",\"mime_type\":\"a\",\"size_in_bytes\":"
  for
    (number, expected) in [
      ("0", 0UL),
      ("-0", 0UL),
      ("10.0", 10UL),
      ("1.2e2", 120UL),
      ("120e-1", 12UL),
    ] {
    let file = @moonfeed.parse_json_feed(prefix + number + "}]}]}").items[0].attachments[0]
    assert_eq(file.size_in_bytes, Some(expected))
    assert_eq(file.title, None)
  }
  for number in ["1e-1", "1e30", "-1e2"] {
    assert_true(
      @test.expect_error(() => {
        @moonfeed.parse_json_feed(prefix + number + "}]}]}")
      })
      is @jsonfeed.InvalidValue("$.items[0].attachments[0].size_in_bytes", _),
    )
  }
}

///|
test "review malformed JSON attachments report exact field paths" {
  let prefix = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"F\",\"items\":[{\"id\":\"a\",\"content_text\":\"x\",\"attachments\":"
  for
    (value, path) in [
      ("null", "$.items[0].attachments"),
      ("[{}]", "$.items[0].attachments[0].url"),
      ("[{\"url\":\"u\"}]", "$.items[0].attachments[0].mime_type"),
      (
        "[{\"url\":\"u\",\"mime_type\":\"a\",\"size_in_bytes\":-1}]", "$.items[0].attachments[0].size_in_bytes",
      ),
      (
        "[{\"url\":\"u\",\"mime_type\":\"a\",\"size_in_bytes\":1.5}]", "$.items[0].attachments[0].size_in_bytes",
      ),
      (
        "[{\"url\":\"u\",\"mime_type\":\"a\",\"size_in_bytes\":18446744073709551616}]",
        "$.items[0].attachments[0].size_in_bytes",
      ),
      (
        "[{\"url\":\"u\",\"mime_type\":\"a\",\"duration_in_seconds\":-0.1}]", "$.items[0].attachments[0].duration_in_seconds",
      ),
      (
        "[{\"url\":\"u\",\"mime_type\":\"a\",\"duration_in_seconds\":\"2\"}]", "$.items[0].attachments[0].duration_in_seconds",
      ),
    ] {
    let error = @test.expect_error(() => {
      @moonfeed.parse_json_feed(prefix + value + "}]}")
    })
    match error {
      @jsonfeed.MissingField(actual)
      | @jsonfeed.InvalidType(actual, _)
      | @jsonfeed.InvalidValue(actual, _) => assert_eq(actual, path)
      _ => fail("expected attachment field error")
    }
  }
}

///|
test "review explicit JSON and automatic APIs accept the same leading BOM" {
  let input = "\u{FEFF}{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"BOM\",\"items\":[]}"
  assert_eq(@moonfeed.parse_json_feed(input), @moonfeed.parse(input))
  assert_eq(@moonfeed.parse(input).title, "BOM")
  let rss = "\u{FEFF}<rss version=\"2.0\"><channel><title>BOM</title><link>u</link><description>D</description></channel></rss>"
  assert_eq(@moonfeed.parse_rss(rss), @moonfeed.parse(rss))
  assert_true(@moonfeed.detect_format(rss) is @moonfeed.FeedFormat::Rss)
}

///|
test "review RSS default namespace reset and foreign core fields are isolated" {
  let feed = @moonfeed.parse_rss(
    (
      #|<rss xmlns="" version="2.0"><channel><title xmlns="urn:foreign">Wrong</title><title>News</title><link>https://example.org/</link><description>D</description><language>zh-CN</language><item xmlns="urn:foreign"><title>Ignored</title></item><item><guid>one</guid><title>Article</title></item></channel></rss>
    ),
  )
  assert_eq(feed.title, "News")
  assert_eq(feed.items.length(), 1)
  assert_eq(feed.items[0].id, "one")
  assert_eq(feed.items[0].language, Some("zh-CN"))
}

///|
test "review RSS rejects character data outside its document root" {
  let xml = "<rss version=\"2.0\"><channel><title>F</title><link>u</link><description>D</description></channel></rss>"
  for input in ["junk" + xml, xml + "junk", "<![CDATA[]]>" + xml] {
    assert_true(
      @test.expect_error(() => @moonfeed.parse_rss(input)) is @rss.InvalidXml(_),
    )
  }
}

///|
test "review podcast namespace bindings obey element scope and sibling restoration" {
  let podcast = @moonfeed.parse_podcast_rss(
    (
      #|<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>F</title><link>u</link><description>D</description><itunes:author xmlns:itunes="urn:foreign">Wrong</itunes:author><item><title>A</title><guid>a</guid><itunes:duration xmlns:itunes="urn:foreign">bad</itunes:duration></item><item><title>B</title><guid>b</guid><itunes:duration>1:02</itunes:duration></item></channel></rss>
    ),
  )
  assert_eq(podcast.show.author, None)
  assert_eq(podcast.episodes[0].duration_in_seconds, None)
  assert_eq(podcast.episodes[1].duration_in_seconds, Some(62.0))
  let scoped = @moonfeed.parse_podcast_rss(
    (
      #|<rss version="2.0"><channel><title>F</title><link>u</link><description>D</description><itunes:author xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">Local</itunes:author></channel></rss>
    ),
  )
  assert_eq(scoped.show.author, Some("Local"))
}

///|
test "review oversized RSS date components cannot wrap to valid instants" {
  assert_true(
    @test.expect_error(() => {
      @moonfeed.parse_rss_datetime("01 Oct 4294969322 12:00:00 GMT")
    })
    is @datetime.InvalidYear,
  )
  assert_true(
    @test.expect_error(() => {
      @moonfeed.parse_rss_datetime("4294967297 Oct 2026 12:00:00 GMT")
    })
    is @datetime.InvalidDay,
  )
  assert_true(
    @test.expect_error(() => {
      @moonfeed.parse_rss_datetime("01 Oct 2026 4294967308:00:00 GMT")
    })
    is @datetime.InvalidTime,
  )
}

///|
test "review XML typed errors retain the underlying failure reason" {
  let error = @test.expect_error(() => {
    @moonfeed.parse_rss("<rss><channel></rss>")
  })
  assert_true(
    error is @rss.InvalidXml(message) && message.contains("mismatched end tag"),
  )
  let atom_error = @test.expect_error(() => {
    @moonfeed.parse_atom_document(
      "<feed xmlns=\"http://www.w3.org/2005/Atom\"><entry></feed>",
    )
  })
  assert_true(
    atom_error is @atom.InvalidXml(message) &&
    message.contains("mismatched end tag"),
  )
}

///|
test "review inherited Atom author collections are independent" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-01T12:00:00Z</updated><author><name>Editor</name></author><entry><id>a</id><title>A</title><updated>2026-10-01T12:00:00Z</updated></entry><entry><id>b</id><title>B</title><updated>2026-10-01T12:00:00Z</updated></entry></feed>
  let feed = @moonfeed.parse_atom(input)
  feed.items[0].authors.clear()
  assert_eq(feed.authors.length(), 1)
  assert_eq(feed.items[1].authors[0].name, Some("Editor"))
}

///|
test "review Atom email permits XML-representable RFC2822 DEL in quoted contexts" {
  for
    (encoded, expected) in [
      ("&quot;a&#127;b&quot;@example.org", "\"a\u{7F}b\"@example.org"),
      ("(note&#127;)a@[x&#127;y]", "(note\u{7F})a@[x\u{7F}y]"),
    ] {
    let document = @moonfeed.parse_atom_document(
      strict_entry_xml(
        "<contributor><name>C</name><email>" +
        encoded +
        "</email></contributor><content/>",
      ),
    )
    match document {
      @moonfeed.AtomDocument::EntryDocument(entry) =>
        assert_eq(entry.metadata.contributors[0].email, Some(expected))
      _ => fail("expected Entry Document")
    }
  }
  assert_true(
    strict_error(
      strict_entry_xml(
        "<contributor><name>C</name><email>a&#127;@example.org</email></contributor><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.contributor[0].email", _),
  )
}

///|
test "review unsupported obsolete email quoted line break is explicitly diagnosed" {
  // RFC 2822 section 4.1 permits a quoted-pair containing LF. The current
  // header scanner deliberately does not implement this obsolete production.
  let error = strict_error(
    strict_entry_xml(
      "<contributor><name>C</name><email>&quot;a\\&#10;b&quot;@example.org</email></contributor><content/>",
    ),
  )
  assert_true(
    error is @atom.InvalidRequiredField("entry.contributor[0].email", _),
  )
  assert_true(
    strict_error(
      strict_entry_xml("<content type='text/plain; x=&#127;'>Body</content>"),
    )
    is @atom.InvalidRequiredField("entry.content.type", _),
  )
}
