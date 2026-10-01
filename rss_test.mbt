///|
test "minimal RSS parses through XML dependency" {
  let feed = @moonfeed.parse_rss(
    (
      #|<rss version="2.0"><channel><title>MoonFeed</title><link>https://example.org/</link><description>News</description></channel></rss>
    ),
  )
  @test.assert_eq(feed.title, "MoonFeed")
  @test.assert_eq(feed.home_page_url, Some("https://example.org/"))
  @test.assert_eq(feed.description, Some("News"))
  assert_true(feed.items.is_empty())
}

///|
test "RSS CDATA entities categories and enclosure normalize" {
  let feed = @moonfeed.parse_rss(
    (
      #|<?xml version="1.0"?><rss version="2.0"><channel><title>Tech &amp; More</title><link>https://example.org/</link><description>Blog</description><category>MoonBit</category><item><title>One &lt;two&gt;</title><description><![CDATA[<p>Hello</p>]]></description><author>writer@example.org</author><category>News</category><guid isPermaLink="false">entry-1</guid><pubDate>Wed, 02 Oct 2002 13:00:00 GMT</pubDate><enclosure url="https://example.org/a.mp3" type="audio/mpeg" length="42"/></item></channel></rss>
    ),
  )
  @test.assert_eq(feed.title, "Tech & More")
  @test.assert_eq(feed.categories, ["MoonBit"])
  let item = feed.items[0]
  @test.assert_eq(item.title, Some("One <two>"))
  @test.assert_eq(item.content_html, Some("<p>Hello</p>"))
  @test.assert_eq(item.id, "entry-1")
  @test.assert_eq(item.published, Some("Wed, 02 Oct 2002 13:00:00 GMT"))
  @test.assert_eq(item.categories, ["News"])
  @test.assert_eq(item.authors[0].name, Some("writer@example.org"))
  @test.assert_eq(item.attachments[0].url, "https://example.org/a.mp3")
  @test.assert_eq(item.attachments[0].mime_type, "audio/mpeg")
  @test.assert_eq(item.attachments[0].size_in_bytes, Some(42UL))
}

///|
test "RSS link is stable identity fallback" {
  let feed = @moonfeed.parse_rss(
    (
      #|<rss version="2.0"><channel><title>x</title><link>https://example.org/</link><description>x</description><item><description>y</description><link>https://example.org/y</link></item></channel></rss>
    ),
  )
  @test.assert_eq(feed.items[0].id, "https://example.org/y")
}

///|
fn rss_error(input : String) -> @rss.ParseError raise {
  @test.expect_error(() => @moonfeed.parse_rss(input))
}

///|
test "RSS typed errors identify required fields" {
  assert_true(
    rss_error("<rss version=\"1.0\"/>") is @rss.UnsupportedRssVersion(_),
  )
  assert_true(rss_error("<rss version=\"2.0\"/>") is @rss.MissingChannel)
  assert_true(
    rss_error("<rss version=\"2.0\"><channel/></rss>")
    is @rss.MissingChannelTitle,
  )
  assert_true(
    rss_error("<rss version=\"2.0\"><channel><title>x</title></channel></rss>")
    is @rss.MissingChannelLink,
  )
  assert_true(
    rss_error(
      "<rss version=\"2.0\"><channel><title>x</title><link>x</link></channel></rss>",
    )
    is @rss.MissingChannelDescription,
  )
  assert_true(
    rss_error(
      "<rss version=\"2.0\"><channel><title>x</title><link>x</link><description>x</description><item><title>x</title></item></channel></rss>",
    )
    is @rss.InvalidRequiredField(_, _),
  )
}

///|
test "RSS channel metadata and repeated categories" {
  let channel = @rss.parse_raw(
    (
      #|<rss version="2.0"><channel><title>x</title><link>https://x</link><description>d</description><language>en</language><pubDate>old</pubDate><lastBuildDate>new</lastBuildDate><managingEditor>e</managingEditor><webMaster>w</webMaster><category domain="a">one</category><category>two</category><generator>g</generator><docs>docs</docs><ttl>15</ttl><image><url>i</url><title>it</title><link>l</link><width>10</width><height>20</height><description>id</description></image></channel></rss>
    ),
  )
  @test.assert_eq(channel.language, Some("en"))
  @test.assert_eq(channel.last_build_date, Some("new"))
  @test.assert_eq(channel.categories.length(), 2)
  @test.assert_eq(channel.ttl, Some(15UL))
  @test.assert_eq(channel.image.unwrap().width, Some(10UL))
  let feed = @rss.normalize(channel)
  @test.assert_eq(feed.updated, Some("new"))
  @test.assert_eq(feed.authors[0].name, Some("e"))
}

///|
test "RSS pubDate is used when lastBuildDate is absent" {
  let feed = @moonfeed.parse_rss(
    (
      #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><pubDate>published</pubDate></channel></rss>
    ),
  )
  @test.assert_eq(feed.updated, Some("published"))
}

///|
test "RSS description is retained in summary and HTML" {
  let feed = @moonfeed.parse_rss(
    (
      #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><item><guid>description-item</guid><description>plain &amp; text</description></item></channel></rss>
    ),
  )
  @test.assert_eq(feed.items[0].summary, Some("plain & text"))
  @test.assert_eq(feed.items[0].content_html, Some("plain & text"))
}

///|
test "RSS missing guid and link is rejected without random identity" {
  assert_true(
    rss_error(
      (
        #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><item><title>orphan</title></item></channel></rss>
      ),
    )
    is @rss.InvalidRequiredField("channel.item[0].id", _),
  )
}

///|
test "RSS malformed XML is typed" {
  let bad_one = "<rss version=\"2.0\"><channel>"
  assert_true(rss_error(bad_one) is @rss.InvalidXml(_))
  let bad_two = "<rss version=\"2.0\"><channel><title>x</title></channel>"
  assert_true(rss_error(bad_two) is @rss.InvalidXml(_))
}

///|
test "RSS enclosure attributes are required and numeric" {
  assert_true(
    rss_error(
      (
        #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><item><title>x</title><enclosure type="audio/mpeg" length="1"/></item></channel></rss>
      ),
    )
    is @rss.InvalidEnclosure("channel.item[0].enclosure.url", _),
  )
  assert_true(
    rss_error(
      (
        #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><item><title>x</title><enclosure url="u" type="audio/mpeg" length="bad"/></item></channel></rss>
      ),
    )
    is @rss.InvalidEnclosure("channel.item[0].enclosure.length", _),
  )
}

///|
test "RSS self closing item fields remain optional" {
  let channel = @rss.parse_raw(
    (
      #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><item><title>x</title><guid>g</guid></item></channel></rss>
    ),
  )
  @test.assert_eq(channel.items[0].description, None)
  assert_true(channel.items[0].enclosure is None)
}

///|
test "RSS rejects wrong root and missing version" {
  let wrong_root = "<feed><channel/></feed>"
  assert_true(rss_error(wrong_root) is @rss.InvalidRequiredField("rss", _))
  let missing_version = "<rss><channel/></rss>"
  assert_true(rss_error(missing_version) is @rss.UnsupportedRssVersion(""))
}
