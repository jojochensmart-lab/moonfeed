///|
test "JSON Feed normalized dates" {
  let feed = @moonfeed.parse_json_feed(
    "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Dates\",\"items\":[{\"id\":\"one\",\"content_text\":\"x\",\"date_published\":\"2026-10-03T20:00:00+08:00\",\"date_modified\":\"2026-10-03T07:00:00-05:00\"}]}",
  )
  @test.assert_eq(feed.items[0].published, Some("2026-10-03T20:00:00+08:00"))
  @test.assert_eq(feed.items[0].published_at.unwrap().unix_seconds, 1791028800L)
  @test.assert_eq(feed.items[0].updated_at.unwrap().unix_seconds, 1791028800L)
}

///|
test "RSS dates normalize channel updated and item published fields" {
  let feed = @moonfeed.parse_rss(
    "<rss version=\"2.0\"><channel><title>Dates</title><link>home</link><description>d</description><pubDate>Wed, 02 Oct 2002 13:00:00 GMT</pubDate><lastBuildDate>Wed, 02 Oct 2002 15:00:00 +0200</lastBuildDate><item><title>Entry</title><guid>one</guid><pubDate>02 Oct 2002 13:00:00 UTC</pubDate></item></channel></rss>",
  )
  @test.assert_eq(feed.updated, Some("Wed, 02 Oct 2002 15:00:00 +0200"))
  @test.assert_eq(feed.updated_at.unwrap().unix_seconds, 1033563600L)
  @test.assert_eq(feed.items[0].published, Some("02 Oct 2002 13:00:00 UTC"))
  @test.assert_eq(feed.items[0].published_at.unwrap().unix_seconds, 1033563600L)
}

///|
test "Atom dates normalize required and optional fields" {
  let feed = @moonfeed.parse(
    "<feed><id>f</id><title>Dates</title><updated>2026-10-03T20:00:00+08:00</updated><entry><id>e</id><title>Entry</title><updated>2026-10-03T12:00:00Z</updated><published>2026-10-03T09:00:00-03:00</published></entry></feed>",
  )
  @test.assert_eq(feed.updated, Some("2026-10-03T20:00:00+08:00"))
  @test.assert_eq(feed.updated_at.unwrap().unix_seconds, 1791028800L)
  @test.assert_eq(feed.items[0].updated_at.unwrap().unix_seconds, 1791028800L)
  @test.assert_eq(feed.items[0].published, Some("2026-10-03T09:00:00-03:00"))
  @test.assert_eq(feed.items[0].published_at.unwrap().unix_seconds, 1791028800L)
  let optional_bad = @moonfeed.parse(
    "<feed><id>f</id><title>Dates</title><updated>2026-10-03T12:00:00Z</updated><entry><id>e</id><title>Entry</title><updated>2026-10-03T12:00:00Z</updated><published>unknown</published></entry></feed>",
  )
  @test.assert_eq(optional_bad.items[0].published, Some("unknown"))
  @test.assert_eq(optional_bad.items[0].published_at, None)
}

///|
test "invalid optional JSON and RSS dates preserve raw strings" {
  let json = @moonfeed.parse_json_feed(
    "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Dates\",\"items\":[{\"id\":\"one\",\"content_text\":\"x\",\"date_published\":\"invalid\"}]}",
  )
  @test.assert_eq(json.items[0].published, Some("invalid"))
  @test.assert_eq(json.items[0].published_at, None)
  let rss = @moonfeed.parse_rss(
    "<rss version=\"2.0\"><channel><title>Dates</title><link>home</link><description>d</description><pubDate>invalid</pubDate><item><title>Entry</title><guid>one</guid><pubDate>invalid</pubDate></item></channel></rss>",
  )
  @test.assert_eq(rss.updated, Some("invalid"))
  @test.assert_eq(rss.updated_at, None)
  @test.assert_eq(rss.items[0].published, Some("invalid"))
  @test.assert_eq(rss.items[0].published_at, None)
}

///|
test "invalid required Atom updated returns typed datetime error" {
  assert_true(
    try {
      let _ = @moonfeed.parse(
        "<feed><id>f</id><title>Dates</title><updated>2026-02-30T12:00:00Z</updated></feed>",
      )
      false
    } catch {
      @moonfeed.Atom(
        @atom.InvalidDateTime("feed.updated", @datetime.InvalidDay)
      ) => true
      _ => false
    },
  )
  assert_true(
    try {
      let _ = @moonfeed.parse(
        "<feed><id>f</id><title>Dates</title><updated>2026-10-03T12:00:00Z</updated><entry><id>e</id><title>Entry</title><updated>2026-02-30T12:00:00Z</updated></entry></feed>",
      )
      false
    } catch {
      @moonfeed.Atom(
        @atom.InvalidDateTime("feed.entry[0].updated", @datetime.InvalidDay)
      ) => true
      _ => false
    },
  )
}

///|
test "root date parser helpers expose the normalized datetime API" {
  let rfc = @moonfeed.parse_rfc3339("2002-10-02T13:00:00Z")
  let rss = @moonfeed.parse_rss_datetime("Wed, 02 Oct 2002 13:00:00 GMT")
  let general = @moonfeed.parse_datetime("2002-10-02T15:00:00+02:00")
  @test.assert_eq(rfc.unix_seconds, rss.unix_seconds)
  @test.assert_eq(rss.unix_seconds, general.unix_seconds)
  @test.assert_eq(rss.compare(rfc), 0)
}
