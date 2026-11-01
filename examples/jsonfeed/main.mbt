///|
fn main {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"MoonBit News","language":"zh-CN","items":[{"id":"release","content_text":"A new release","date_published":"2026-10-01T20:00:00+08:00","attachments":[{"url":"https://example.org/audio.mp3","mime_type":"audio/mpeg","size_in_bytes":42,"duration_in_seconds":12.5}]}]}
  try {
    let feed : @moonfeed.Feed = @moonfeed.parse_json_feed(input)
    assert_eq(feed.title, "MoonBit News")
    assert_eq(feed.items.length(), 1)
    assert_eq(feed.items[0].language, Some("zh-CN"))
    assert_eq(feed.items[0].attachments[0].size_in_bytes, Some(42UL))
    assert_eq(feed.items[0].published_at.unwrap().unix_seconds, 1790856000L)
    println("JSON Feed: PASS (content, language, attachment, UTC date)")
  } catch {
    _ => abort("JSON Feed example failed")
  }
}
