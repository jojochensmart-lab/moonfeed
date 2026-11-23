///|
fn acceptance_rss(items : String) -> String {
  "<rss version='2.0'><channel><title>News</title><link>https://example.org/</link><description>Feed</description>" +
  items +
  "</channel></rss>"
}

///|
test "formal RSS description alone needs neither guid nor link" {
  let input = acceptance_rss(
    "<item><description>这是一条新闻正文</description></item>",
  )
  let raw = @rss.parse_raw(input)
  assert_true(raw.items[0].guid is None)
  assert_eq(raw.items[0].link, None)
  let feed = @moonfeed.parse_rss(input)
  assert_eq(feed, @moonfeed.parse(input))
  assert_eq(feed.items.length(), 1)
  let item = feed.items[0]
  assert_eq(item.id, "")
  assert_eq(item.url, None)
  assert_eq(item.title, None)
  assert_eq(item.summary, Some("这是一条新闻正文"))
  assert_eq(item.content_html, Some("这是一条新闻正文"))
  assert_eq(@rss.normalize(raw), feed)
  assert_eq(@moonfeed.parse_podcast_rss(input).feed, feed)
}

///|
test "formal RSS title alone needs neither guid nor link" {
  let item = @moonfeed.parse_rss(
      acceptance_rss("<item><title>只有标题的新闻</title></item>"),
    ).items[0]
  assert_eq(item.title, Some("只有标题的新闻"))
  assert_eq(item.id, "")
  assert_eq(item.url, None)
  assert_eq(item.summary, None)
  assert_eq(item.content_html, None)
}

///|
test "formal RSS title and description do not imply an identity" {
  let item = @moonfeed.parse_rss(
      acceptance_rss(
        "<item><title>新闻标题</title><description>新闻正文</description></item>",
      ),
    ).items[0]
  assert_eq(item.title, Some("新闻标题"))
  assert_eq(item.content_html, Some("新闻正文"))
  assert_eq(item.id, "")
  assert_eq(item.url, None)
}

///|
test "formal RSS guid takes priority and link fallback retains its meaning" {
  let input = acceptance_rss(
    "<item><title>All</title><description>Body</description><guid isPermaLink='false'>opaque-id</guid><link>https://example.org/a</link></item>" +
    "<item><description>Guid only identity</description><guid>https://example.org/g</guid></item>" +
    "<item><title>Link identity</title><link>https://example.org/l</link></item>",
  )
  let raw = @rss.parse_raw(input)
  assert_true(
    raw.items[0].guid is Some({ value: "opaque-id", is_permalink: false, }),
  )
  assert_true(
    raw.items[1].guid
    is Some({ value: "https://example.org/g", is_permalink: true, }),
  )
  let items = @moonfeed.parse_rss(input).items
  assert_eq(items.length(), 3)
  assert_eq(items[0].id, "opaque-id")
  assert_eq(items[0].url, Some("https://example.org/a"))
  assert_eq(items[0].content_html, Some("Body"))
  assert_eq(items[1].id, "https://example.org/g")
  assert_eq(items[1].url, None)
  assert_eq(items[2].id, "https://example.org/l")
  assert_eq(items[2].url, Some("https://example.org/l"))
}

///|
test "formal RSS missing both content fields remains invalid even with identity" {
  for
    fields in [
      "", "<guid>id</guid>", "<link>https://example.org/a</link>", "<guid>id</guid><link>https://example.org/a</link>",
      "<x:title xmlns:x='urn:extension'>Not a core title</x:title>",
    ] {
    let input = acceptance_rss("<item>" + fields + "</item>")
    assert_true(
      @test.expect_error(() => @moonfeed.parse_rss(input))
      is @rss.InvalidRequiredField("channel.item[0].title|description", _),
    )
    assert_true(
      @test.expect_error(() => @rss.parse_raw(input))
      is @rss.InvalidRequiredField("channel.item[0].title|description", _),
    )
  }
}

///|
test "formal RSS ordered items retain absent identities without synthetic values" {
  let items = @moonfeed.parse_rss(
      acceptance_rss(
        "<item><description>Body</description></item>" +
        "<item><title>Titled</title><guid>known</guid></item>" +
        "<item><description>Body</description></item>" +
        "<item><title>Linked</title><link>https://example.org/l</link></item>",
      ),
    ).items
  assert_eq(items.length(), 4)
  assert_eq(items.map(item => item.id), [
    "", "known", "", "https://example.org/l",
  ])
  assert_eq(items.map(item => item.url), [
    None,
    None,
    None,
    Some("https://example.org/l"),
  ])
  assert_eq(items[0].content_html, Some("Body"))
  assert_eq(items[2].content_html, Some("Body"))
}

///|
test "formal RSS direct normalization still enforces title or description" {
  let channel = @rss.parse_raw(acceptance_rss("<item><title>T</title></item>"))
  let item = channel.items[0]
  channel.items[0] = {
    ..item,
    title: None,
    guid: Some({ value: "id", is_permalink: false, }),
  }
  assert_true(
    @test.expect_error(() => @rss.normalize(channel))
    is @rss.InvalidRequiredField("channel.item[0].title|description", _),
  )
}

///|
test "formal RSS accepts XML Misc and rejects malformed document boundaries" {
  let xml = acceptance_rss(
    "<item><guid>id</guid><description><![CDATA[<p>Body</p>]]>&amp;</description></item>",
  )
  let feed = @moonfeed.parse_rss(xml)
  assert_eq(feed.items[0].content_html, Some("<p>Body</p>&"))
  for
    (prefix, suffix) in [
      ("", ""),
      (" \t\r\n", " \t\r\n"),
      ("<!--before-->", "<!-- valid trailing comment -->"),
      ("<?audit before?>", "<?audit complete?>"),
    ] {
    assert_eq(@moonfeed.parse_rss(prefix + xml + suffix), feed)
    assert_eq(@moonfeed.parse(prefix + xml + suffix), feed)
  }
  for
    input in [
      "INVALID" + xml,
      xml + "INVALID",
      xml + "<other/>",
      xml + "<incomplete",
      xml + "<!-- invalid -- comment -->",
      xml + "<?audit incomplete",
      xml + "<?xml version='1.0'?>",
    ] {
    assert_true(
      @test.expect_error(() => @moonfeed.parse_rss(input)) is @rss.InvalidXml(_),
    )
  }
  assert_true(
    @test.expect_error(() => @moonfeed.parse(xml + "INVALID"))
    is @moonfeed.Rss(@rss.InvalidXml("character data outside document element")),
  )
}

///|
test "formal XML boundaries apply to Atom Feed and prefixed standalone Entry" {
  let feed_xml = "<feed xmlns='http://www.w3.org/2005/Atom'><id>urn:feed:1</id><title>Feed</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author></feed>"
  let entry_xml = "<a:entry xmlns:a='http://www.w3.org/2005/Atom' xmlns:x='urn:extension'><a:id>urn:entry:1</a:id><a:title>Entry</a:title><a:updated>2003-12-13T18:30:02Z</a:updated><a:author><a:name>A</a:name></a:author><x:title>Ignored</x:title><a:content><![CDATA[Body]]>&amp;</a:content></a:entry>"
  let feed = @moonfeed.parse_atom(
    "<!--lead-->" + feed_xml + "<?audit complete?>",
  )
  assert_eq(feed.title, "Feed")
  assert_eq(feed.authors[0].name, Some("A"))
  match
    @moonfeed.parse_atom_document(
      "<?audit before?>" + entry_xml + "<!--tail-->",
    ) {
    @atom.EntryDocument(entry) => {
      assert_eq(entry.metadata.id, Some("urn:entry:1"))
      assert_eq(entry.metadata.title.unwrap().value, "Entry")
      assert_eq(entry.content.unwrap().value, "Body&")
      assert_true(
        entry.metadata.raw.content[4]
        is @atom.Element(
          { namespace_uri: Some("urn:extension"), local_name: "title", .. }
        ),
      )
    }
    _ => fail("expected standalone Entry")
  }
  for xml in [feed_xml, entry_xml] {
    for
      invalid in [
        "INVALID" + xml,
        xml + "INVALID",
        xml + "<other/>",
        xml + "<![CDATA[]]>",
      ] {
      assert_true(
        @test.expect_error(() => @moonfeed.parse_atom_document(invalid))
        is @atom.InvalidXml(_),
      )
    }
  }
  assert_true(
    @test.expect_error(() => @moonfeed.parse_atom(feed_xml + "INVALID"))
    is @atom.InvalidXml(_),
  )
}
