///|
fn atom_error(input : String) -> @atom.ParseError raise {
  @test.expect_error(() => @moonfeed.parse_atom(input))
}

///|
test "Atom minimal feed uses required fields and empty entries" {
  let feed = @moonfeed.parse_atom(@atoms.minimal)
  @test.assert_eq(feed.title, "Minimal")
  @test.assert_eq(feed.updated, Some("2026-10-01T10:00:00Z"))
  assert_true(feed.items.is_empty())
}

///|
test "Atom full fixture normalizes feed and entry fields" {
  let feed = @moonfeed.parse_atom(@atoms.full)
  @test.assert_eq(feed.title, "News &amp; Updates")
  @test.assert_eq(feed.description, Some("Short summary"))
  @test.assert_eq(feed.feed_url, Some("https://example.org/feed.atom"))
  @test.assert_eq(feed.home_page_url, Some("https://example.org/"))
  @test.assert_eq(feed.authors[0].name, Some("Editor"))
  @test.assert_eq(feed.authors[0].url, Some("https://example.org/editor"))
  @test.assert_eq(feed.categories, ["moonbit"])
  let item = feed.items[0]
  @test.assert_eq(item.id, "urn:entry:one")
  @test.assert_eq(item.url, Some("https://example.org/releases/1"))
  @test.assert_eq(item.updated, Some("2026-10-01T09:00:00Z"))
  @test.assert_eq(item.published, Some("2026-09-30T09:00:00Z"))
  @test.assert_eq(item.summary, Some("First release"))
  @test.assert_eq(item.content_html, Some("<p>Ready &amp; stable</p>"))
  @test.assert_eq(item.categories, ["release"])
  @test.assert_eq(item.authors[0].name, Some("Editor"))
}

///|
test "Atom repeated entries, dates, authors and text content types" {
  let multiple = @moonfeed.parse_atom(@atoms.multiple_entries)
  @test.assert_eq(multiple.items.length(), 2)
  @test.assert_eq(multiple.items[1].id, "two")
  @test.assert_eq(multiple.updated, Some("2024-01-02T03:04:05Z"))
  let input = "<feed xmlns=\"http://www.w3.org/2005/Atom\"><id>f</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><author><name>A</name></author><author><name>B</name></author><entry><id>e</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><published>2024-01-02T03:04:05Z</published><author><name>E</name></author><summary type=\"html\">&lt;b&gt;sum&lt;/b&gt;</summary><content type=\"text\">plain &amp; readable</content></entry><entry><id>i</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><summary>only summary</summary></entry></feed>"
  let feed = @moonfeed.parse_atom(input)
  @test.assert_eq(feed.authors.length(), 2)
  @test.assert_eq(feed.items[0].authors[0].name, Some("E"))
  @test.assert_eq(feed.items[0].summary, Some("<b>sum</b>"))
  @test.assert_eq(feed.items[0].content_text, Some("plain & readable"))
  @test.assert_eq(feed.items[0].published, Some("2024-01-02T03:04:05Z"))
  @test.assert_eq(feed.items[1].authors.length(), 2)
  @test.assert_eq(feed.items[1].summary, Some("only summary"))
}

///|
test "Atom self alternate and enclosure links use relation semantics" {
  let feed = @moonfeed.parse_atom(@atoms.enclosure)
  @test.assert_eq(feed.feed_url, None)
  @test.assert_eq(feed.home_page_url, None)
  let item = feed.items[0]
  @test.assert_eq(item.url, Some("https://example.org/audio"))
  @test.assert_eq(item.attachments.length(), 1)
  @test.assert_eq(item.attachments[0].url, "https://example.org/a.mp3")
  @test.assert_eq(item.attachments[0].mime_type, "audio/mpeg")
  @test.assert_eq(item.attachments[0].size_in_bytes, Some(120UL))
  let release = @moonfeed.parse_atom(@atoms.github_release)
  @test.assert_eq(
    release.feed_url,
    Some("https://github.com/example/project/releases.atom"),
  )
  @test.assert_eq(
    release.home_page_url,
    Some("https://github.com/example/project/releases"),
  )
}

///|
test "Atom missing rel means alternate and self closing links are accepted" {
  let feed = @moonfeed.parse_atom(
    "<feed><id>f</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><link href=\"home\"/><entry><id>e</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><link rel=\"self\" href=\"item-self\"/><link href=\"item-home\"/></entry></feed>",
  )
  @test.assert_eq(feed.home_page_url, Some("home"))
  @test.assert_eq(feed.items[0].url, Some("item-home"))
}

///|
test "Atom prefixed names and extension elements are handled" {
  let feed = @moonfeed.parse_atom(@atoms.namespaced)
  @test.assert_eq(feed.title, "Prefixed")
  @test.assert_eq(feed.items[0].title, Some("A & B"))
}

///|
test "Atom xhtml content reduces markup to readable text" {
  let feed = @moonfeed.parse_atom(
    "<feed><id>f</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><entry><id>e</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><content type=\"xhtml\"><div xmlns=\"http://www.w3.org/1999/xhtml\">Hello <b>Moon</b></div></content></entry></feed>",
  )
  @test.assert_eq(feed.items[0].content_html, Some("Hello Moon"))
  let mixed = @moonfeed.parse_atom(
    "<feed><id>f</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><entry><id>e</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><content type=\"xhtml\"><div>Hello <b>Moon</b> world</div></content></entry></feed>",
  )
  @test.assert_eq(mixed.items[0].content_html, Some("Hello Moon world"))
}

///|
test "Atom realistic blog fixture combines language links and inherited author" {
  let feed = @moonfeed.parse_atom(@atoms.tech_blog)
  @test.assert_eq(feed.language, Some("zh-CN"))
  @test.assert_eq(feed.home_page_url, Some("https://blog.example.org/"))
  @test.assert_eq(feed.items[0].authors[0].name, Some("博主"))
  @test.assert_eq(
    feed.items[0].content_html,
    Some("<p>构建 &amp; 解析</p>"),
  )
}

///|
test "Atom validates root and required feed and entry fields with paths" {
  assert_true(atom_error("<rss/>") is @atom.ParseError::InvalidAtomRoot(_))
  assert_true(
    atom_error(
      "<feed><title>x</title><updated>2024-01-02T03:04:05Z</updated></feed>",
    )
    is @atom.ParseError::InvalidRequiredField("feed.id", _),
  )
  assert_true(
    atom_error("<feed><id>f</id><updated>2024-01-02T03:04:05Z</updated></feed>")
    is @atom.ParseError::InvalidRequiredField("feed.title", _),
  )
  assert_true(
    atom_error("<feed><id>f</id><title>x</title></feed>")
    is @atom.ParseError::InvalidRequiredField("feed.updated", _),
  )
  assert_true(
    atom_error(
      "<feed><id>f</id><title>x</title><updated>2024-01-02T03:04:05Z</updated><entry><title>x</title><updated>2024-01-02T03:04:05Z</updated></entry></feed>",
    )
    is @atom.ParseError::InvalidRequiredField("feed.entry[0].id", _),
  )
  assert_true(
    atom_error(
      "<feed><id>f</id><title>x</title><updated>2024-01-02T03:04:05Z</updated><entry><id>e</id><updated>2024-01-02T03:04:05Z</updated></entry></feed>",
    )
    is @atom.ParseError::InvalidRequiredField("feed.entry[0].title", _),
  )
  assert_true(
    atom_error(
      "<feed><id>f</id><title>x</title><updated>2024-01-02T03:04:05Z</updated><entry><id>e</id><title>x</title></entry></feed>",
    )
    is @atom.ParseError::InvalidRequiredField("feed.entry[0].updated", _),
  )
}

///|
test "Atom invalid XML and required link/category attributes have typed paths" {
  assert_true(atom_error("<feed><id>f</id>") is @atom.ParseError::InvalidXml(_))
  assert_true(
    atom_error("<feed><id>f</id><title>x</feed>")
    is @atom.ParseError::InvalidXml(_),
  )
  assert_true(
    atom_error(
      "<feed><id>f</id><title>x</title><updated>2024-01-02T03:04:05Z</updated><link rel=\"alternate\"/></feed>",
    )
    is @atom.ParseError::InvalidRequiredField("feed.link[0].href", _),
  )
  assert_true(
    atom_error(
      "<feed><id>f</id><title>x</title><updated>2024-01-02T03:04:05Z</updated><category scheme=\"s\"/></feed>",
    )
    is @atom.ParseError::InvalidRequiredField("feed.category[0].term", _),
  )
}

///|
test "Atom fixture category repeats and category errors are scoped" {
  let input = "<feed><id>f</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><category term=\"one\"/><category term=\"two\"/></feed>"
  @test.assert_eq(@moonfeed.parse_atom(input).categories, ["one", "two"])
}

///|
test "Atom malformed enclosure length is rejected" {
  let input = "<feed><id>f</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><entry><id>e</id><title>t</title><updated>2024-01-02T03:04:05Z</updated><link rel=\"enclosure\" href=\"u\" length=\"bad\"/></entry></feed>"
  assert_true(
    atom_error(input)
    is @atom.ParseError::InvalidRequiredField("feed.entry[0].link[0].length", _),
  )
}
