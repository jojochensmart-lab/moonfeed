///|
test "detect reports every supported format" {
  assert_eq(
    detect_name("{\"version\":\"https://jsonfeed.org/version/1.1\"}"),
    Ok("JSON Feed 1.1"),
  )
  assert_eq(detect_name("<rss version=\"2.0\"><channel/></rss>"), Ok("RSS 2.0"))
  assert_eq(
    detect_name("<feed xmlns=\"http://www.w3.org/2005/Atom\"/>"),
    Ok("Atom 1.0"),
  )
}

///|
test "normalized output is valid escaped JSON" {
  let feed = @moonfeed.parse_json_feed(
    "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Moon 月\",\"items\":[{\"id\":\"one\",\"title\":\"quote \\\" and\\\\ slash\",\"content_text\":\"hello\",\"date_published\":\"2026-10-01T12:00:00Z\"}]}",
  )
  let output = feed_json(feed).stringify(indent=2)
  assert_true(output.has_prefix("{"))
  assert_true(output.has_suffix("}"))
  assert_true(output.contains("\\\""))
  assert_true(output.contains("Moon 月"))
  assert_true(output.contains("published_unix"))
}

///|
test "empty collections and attachments serialize consistently" {
  let feed = @moonfeed.parse_rss(
    "<rss version=\"2.0\"><channel><title>F</title><link>https://e.test</link><description>D</description><item><guid>one</guid><description>Episode</description><enclosure url=\"https://e.test/a.mp3\" type=\"audio/mpeg\" length=\"12\"/></item></channel></rss>",
  )
  let output = feed_json(feed).stringify()
  assert_true(output.contains("\"authors\":[]"))
  assert_true(output.contains("\"attachments\":[{"))
}

///|
test "help and version are stable" {
  assert_true(help_text().contains("moonfeed normalize <file|->"))
  assert_eq(VERSION, "0.1.0")
}

///|
test "unknown and malformed input return errors" {
  assert_true(detect_name("<html><body>not a feed</body></html>") is Err(_))
  assert_true(parse_feed("{not json}") is Err(_))
  assert_true(detect_name("") is Err(_))
}
