///|
test "Podcast RSS metadata and duration normalize" {
  let result = @moonfeed.parse_podcast_rss(
    (
      #|<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>Show</title><link>https://example.org/</link><description>General description</description><itunes:author>Host</itunes:author><itunes:owner><itunes:name>Owner</itunes:name><itunes:email>owner@example.org</itunes:email></itunes:owner><itunes:subtitle>Short show summary</itunes:subtitle><itunes:summary><![CDATA[<p>Long show summary</p>]]></itunes:summary><itunes:explicit>clean</itunes:explicit><itunes:image href="https://example.org/show.jpg"/><itunes:category text="Society &amp; Culture"><itunes:category text="Documentary"/></itunes:category><itunes:type>serial</itunes:type><itunes:complete>no</itunes:complete><itunes:new-feed-url>https://example.org/new.xml</itunes:new-feed-url><item><title>Episode 7</title><guid>episode-7</guid><enclosure url="https://example.org/7.mp3" type="audio/mpeg" length="1000"/><itunes:subtitle>Episode subtitle</itunes:subtitle><itunes:summary>Episode summary</itunes:summary><itunes:image href="https://example.org/7.jpg"/><itunes:duration>1:02:03</itunes:duration><itunes:episode>7</itunes:episode><itunes:season>2</itunes:season><itunes:episodeType>full</itunes:episodeType><itunes:explicit>true</itunes:explicit><itunes:block>no</itunes:block></item></channel></rss>,
    ),
  )
  @test.assert_eq(result.feed.title, "Show")
  @test.assert_eq(result.show.author, Some("Host"))
  @test.assert_eq(result.show.owner_name, Some("Owner"))
  @test.assert_eq(result.show.owner_email, Some("owner@example.org"))
  @test.assert_eq(result.show.subtitle, Some("Short show summary"))
  @test.assert_eq(result.show.summary, Some("<p>Long show summary</p>"))
  @test.assert_eq(result.show.explicit, Some(false))
  @test.assert_eq(result.show.image_url, Some("https://example.org/show.jpg"))
  @test.assert_eq(result.show.categories[0].name, "Society & Culture")
  @test.assert_eq(result.show.categories[0].subcategories, ["Documentary"])
  @test.assert_eq(result.show.podcast_type, Some("serial"))
  @test.assert_eq(result.show.complete, Some(false))
  @test.assert_eq(result.show.new_feed_url, Some("https://example.org/new.xml"))
  let episode = result.episodes[0]
  @test.assert_eq(episode.subtitle, Some("Episode subtitle"))
  @test.assert_eq(episode.summary, Some("Episode summary"))
  @test.assert_eq(episode.image_url, Some("https://example.org/7.jpg"))
  @test.assert_eq(episode.duration_in_seconds, Some(3723.0))
  @test.assert_eq(episode.episode_number, Some(7UL))
  @test.assert_eq(episode.season_number, Some(2UL))
  @test.assert_eq(episode.episode_type, Some("full"))
  @test.assert_eq(episode.explicit, Some(true))
  @test.assert_eq(episode.block, Some(false))
  @test.assert_eq(
    result.feed.items[0].attachments[0].duration_in_seconds,
    Some(3723.0),
  )
}

///|
test "Podcast durations accept seconds and minute-second forms" {
  let result = @moonfeed.parse_podcast_rss(
    (
      #|<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>x</title><link>l</link><description>d</description><item><title>a</title><guid>a</guid><itunes:duration>95</itunes:duration></item><item><title>b</title><guid>b</guid><itunes:duration>2:05</itunes:duration></item></channel></rss>,
    ),
  )
  @test.assert_eq(result.episodes[0].duration_in_seconds, Some(95.0))
  @test.assert_eq(result.episodes[1].duration_in_seconds, Some(125.0))
}

///|
test "Podcast extensions require the canonical namespace declaration" {
  let result = @moonfeed.parse_podcast_rss(
    (
      #|<rss version="2.0"><channel><title>x</title><link>l</link><description>d</description><item><title>a</title><guid>a</guid><itunes:duration>90</itunes:duration></item></channel></rss>,
    ),
  )
  @test.assert_eq(result.show.author, None)
  @test.assert_eq(result.episodes[0].duration_in_seconds, None)
  @test.assert_eq(result.feed.items[0].attachments.length(), 0)
}

///|
test "Podcast namespace may be declared on channel" {
  let result = @moonfeed.parse_podcast_rss(
    (
      #|<rss version="2.0"><channel xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><title>x</title><link>l</link><description>d</description><itunes:author>Host</itunes:author></channel></rss>,
    ),
  )
  @test.assert_eq(result.show.author, Some("Host"))
}

///|
fn podcast_error(input : String) -> @rss.ParseError raise {
  @test.expect_error(() => @moonfeed.parse_podcast_rss(input))
}

///|
test "Podcast duration errors identify the extension field" {
  assert_true(
    podcast_error(
      (
        #|<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>x</title><link>l</link><description>d</description><item><title>a</title><guid>a</guid><itunes:duration>1:60</itunes:duration></item></channel></rss>,
      ),
    )
    is @rss.InvalidRequiredField("channel.item[0].itunes:duration", _),
  )
}

///|
test "Podcast boolean metadata rejects ambiguous spellings" {
  assert_true(
    podcast_error(
      (
        #|<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>x</title><link>l</link><description>d</description><itunes:explicit>sometimes</itunes:explicit></channel></rss>,
      ),
    )
    is @rss.InvalidRequiredField("channel.itunes:explicit", _),
  )
}

///|
test "Unified RSS parser includes podcast enclosure duration" {
  let feed = @moonfeed.parse(
    (
      #|<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel><title>x</title><link>l</link><description>d</description><item><title>a</title><guid>a</guid><enclosure url="u" type="audio/mpeg" length="12"/><itunes:duration>3:04</itunes:duration></item></channel></rss>,
    ),
  )
  @test.assert_eq(feed.items[0].attachments[0].duration_in_seconds, Some(184.0))
}
