///|
fn main {
  let input =
    #|<rss version="2.0"><channel><title>News</title><link>https://example.org/</link><description>Updates</description><language>en</language><item><guid isPermaLink="false">release-1</guid><description><![CDATA[<p>Released</p>]]></description><pubDate>Wed, 02 Oct 2002 13:00:00 GMT</pubDate><enclosure url="https://example.org/a.mp3" type="audio/mpeg" length="42"/></item></channel></rss>
  try {
    let feed = @moonfeed.parse_rss(input)
    assert_eq(feed.title, "News")
    assert_eq(feed.items[0].id, "release-1")
    assert_eq(feed.items[0].content_html, Some("<p>Released</p>"))
    assert_eq(feed.items[0].attachments[0].size_in_bytes, Some(42UL))
    assert_eq(feed.items[0].published_at.unwrap().unix_seconds, 1033563600L)
    assert_eq(@moonfeed.parse(input), feed)
    println("RSS: PASS (CDATA, stable ID, enclosure, date, auto detection)")
  } catch {
    _ => abort("RSS example failed")
  }
}
