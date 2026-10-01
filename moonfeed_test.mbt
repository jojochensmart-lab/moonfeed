///|
test "minimal feed" {
  let feed = @moonfeed.parse_json_feed(
    (
      #|{"version":"https://jsonfeed.org/version/1.1","title":"MoonFeed","items":[]}
    ),
  )
  assert_eq(feed.title, "MoonFeed")
  assert_eq(feed.items.length(), 0)
  assert_true(feed.description is None)
}

///|
test "text item is normalized" {
  let feed = @moonfeed.parse_json_feed(
    (
      #|{"version":"https://jsonfeed.org/version/1.1","title":"News","items":[{"id":"one","content_text":"Hello","tags":["MoonBit"],"date_published":"2026-10-01T12:00:00Z"}]}
    ),
  )
  assert_eq(feed.items[0].id, "one")
  assert_true(feed.items[0].content_text == Some("Hello"))
  assert_true(feed.items[0].categories == ["MoonBit"])
  assert_true(feed.items[0].published == Some("2026-10-01T12:00:00Z"))
}
