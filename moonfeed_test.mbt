///|
test "minimal feed" {
  let feed = @moonfeed.parse_json_feed(@samples.minimal)
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

///|
test "full feed metadata and multiple item ordering" {
  let feed = @moonfeed.parse_json_feed(@samples.full)
  assert_eq(feed.title, "MoonFeed 月刊")
  @test.assert_eq(feed.description, Some("MoonBit news"))
  @test.assert_eq(feed.home_page_url, Some("https://example.org/"))
  @test.assert_eq(feed.feed_url, Some("https://example.org/feed.json"))
  @test.assert_eq(feed.language, Some("zh-CN"))
  assert_eq(feed.items.length(), 3)
  assert_eq(feed.items[0].id, "first")
  assert_eq(feed.items[1].id, "second")
  assert_eq(feed.items[2].id, "third")
  assert_true(feed.categories.is_empty())
  assert_true(feed.updated is None)
}

///|
test "complete item mapping preserves content and dates" {
  let item = @moonfeed.parse_json_feed(@samples.full).items[0]
  @test.assert_eq(item.title, Some("First post"))
  @test.assert_eq(item.url, Some("https://example.org/first"))
  @test.assert_eq(item.external_url, Some("https://moonbitlang.com/"))
  @test.assert_eq(item.summary, Some("A summary"))
  @test.assert_eq(item.content_text, Some("Hello 🌙\nMoonBit"))
  @test.assert_eq(item.content_html, Some("<p>Hello &amp; MoonBit</p>"))
  @test.assert_eq(item.published, Some("2026-10-01T12:00:00+08:00"))
  @test.assert_eq(item.updated, Some("2026-10-01T13:00:00+08:00"))
  @test.assert_eq(item.categories, ["MoonBit", "新闻"])
  assert_true(item.attachments.is_empty())
}

///|
test "author inheritance override and explicit empty authors" {
  let feed = @moonfeed.parse_json_feed(@samples.full)
  @test.assert_eq(feed.authors[0].name, Some("Editor"))
  @test.assert_eq(feed.authors[0].url, Some("https://example.org/editor"))
  @test.assert_eq(
    feed.authors[0].avatar,
    Some("https://example.org/avatar.png"),
  )
  @test.assert_eq(feed.items[0].authors, feed.authors)
  @test.assert_eq(feed.items[1].authors[0].name, Some("Guest"))
  assert_true(feed.items[2].authors.is_empty())
  feed.items[0].authors.clear()
  assert_eq(feed.authors.length(), 1)
}

///|
test "HTML only empty text and language normalization" {
  let feed = @moonfeed.parse_json_feed(@samples.full)
  assert_true(feed.items[1].content_text is None)
  @test.assert_eq(feed.items[1].content_html, Some("<p>Second</p>"))
  @test.assert_eq(feed.items[2].content_text, Some(""))
  @test.assert_eq(feed.items[0].language, Some("zh-CN"))
  @test.assert_eq(feed.items[1].language, Some("en"))
  assert_true(feed.items[2].categories.is_empty())
}

///|
fn parse_error(input : String) -> @jsonfeed.ParseError raise {
  @test.expect_error(() => @moonfeed.parse_json_feed(input))
}

///|
test "invalid JSON never returns partial data" {
  assert_true(parse_error(@malformed.invalid_json) is @jsonfeed.InvalidJson(_))
  assert_true(parse_error("") is @jsonfeed.InvalidJson(_))
  assert_true(
    parse_error(@samples.minimal + " garbage") is @jsonfeed.InvalidJson(_),
  )
}

///|
test "required top level fields have actionable paths" {
  @test.assert_eq(parse_error("{}"), @jsonfeed.MissingField("$.version"))
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","items":[]}
      ),
    ),
    @jsonfeed.MissingField("$.title"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x"}
      ),
    ),
    @jsonfeed.MissingField("$.items"),
  )
}

///|
test "unsupported versions are explicit" {
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1","title":"x","items":[]}
      ),
    ),
    @jsonfeed.UnsupportedVersion("https://jsonfeed.org/version/1"),
  )
}

///|
test "missing id and missing content are rejected" {
  @test.assert_eq(
    parse_error(@malformed.missing_id),
    @jsonfeed.MissingField("$.items[0].id"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":[{"id":"a"}]}
      ),
    ),
    @jsonfeed.MissingField("$.items[0].content_text|content_html"),
  )
}

///|
test "wrong JSON shapes and null optional values are rejected" {
  @test.assert_eq(parse_error("[]"), @jsonfeed.InvalidType("$", "object"))
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":3,"items":[]}
      ),
    ),
    @jsonfeed.InvalidType("$.title", "string"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":{}}
      ),
    ),
    @jsonfeed.InvalidType("$.items", "array"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","description":null,"items":[]}
      ),
    ),
    @jsonfeed.InvalidType("$.description", "string"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":[42]}
      ),
    ),
    @jsonfeed.InvalidType("$.items[0]", "object"),
  )
}

///|
test "invalid tags report the element path" {
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":[{"id":"a","content_text":"x","tags":["ok",4]}]}
      ),
    ),
    @jsonfeed.InvalidType("$.items[0].tags[1]", "string"),
  )
}

///|
test "empty and malformed authors are rejected" {
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","authors":[{}],"items":[]}
      ),
    ),
    @jsonfeed.InvalidValue("$.authors[0]", "author needs name, url or avatar"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","authors":[{"name":7}],"items":[]}
      ),
    ),
    @jsonfeed.InvalidType("$.authors[0].name", "string"),
  )
}

///|
test "empty duplicate and numeric item identifiers are rejected" {
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":[{"id":"","content_text":"x"}]}
      ),
    ),
    @jsonfeed.InvalidValue("$.items[0].id", "id must not be empty"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":[{"id":"a","content_text":"x"},{"id":"a","content_text":"y"}]}
      ),
    ),
    @jsonfeed.InvalidValue("$.items[1].id", "duplicate item id"),
  )
  @test.assert_eq(
    parse_error(
      (
        #|{"version":"https://jsonfeed.org/version/1.1","title":"x","items":[{"id":1,"content_text":"x"}]}
      ),
    ),
    @jsonfeed.InvalidType("$.items[0].id", "string"),
  )
}

///|
test "extensions and unsupported fields are ignored" {
  let feed = @moonfeed.parse_json_feed(
    (
      #|{"version":"https://jsonfeed.org/version/1.1","title":"x","_custom":{},"items":[{"id":"a","content_text":"x","attachments":[{"url":"https://example.org/a.mp3","mime_type":"audio/mpeg"}]}]}
    ),
  )
  assert_true(feed.items[0].attachments.is_empty())
}
