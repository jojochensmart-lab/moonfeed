///|
fn format_error(input : String) -> @detect.DetectError raise {
  @test.expect_error(() => @detect.detect_format(input))
}

///|
fn unified_error(input : String) -> @moonfeed.ParseError raise {
  @test.expect_error(() => @moonfeed.parse(input))
}

///|
test "format detector identifies each supported family" {
  @test.assert_eq(
    @detect.detect_format(@samples.minimal),
    @detect.FeedFormat::JsonFeed,
  )
  @test.assert_eq(
    @detect.detect_format("<rss version=\"2.0\"><channel/></rss>"),
    @detect.FeedFormat::Rss,
  )
  @test.assert_eq(
    @detect.detect_format(@atoms.minimal),
    @detect.FeedFormat::Atom,
  )
}

///|
test "format detector skips leading whitespace and UTF-8 BOM" {
  @test.assert_eq(
    @detect.detect_format(" \r\n\t" + @samples.minimal),
    @detect.FeedFormat::JsonFeed,
  )
  @test.assert_eq(
    @detect.detect_format(" \r\n\t<rss version=\"2.0\">"),
    @detect.FeedFormat::Rss,
  )
  @test.assert_eq(
    @detect.detect_format("\u{FEFF}  " + @atoms.minimal),
    @detect.FeedFormat::Atom,
  )
  let bom_json = "\u{FEFF}  " + @samples.minimal
  @test.assert_eq(@moonfeed.parse(bom_json).title, "MoonFeed")
}

///|
test "format detector skips XML declaration and leading comments" {
  @test.assert_eq(
    @detect.detect_format(
      " \n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<rss version=\"2.0\">",
    ),
    @detect.FeedFormat::Rss,
  )
  @test.assert_eq(
    @detect.detect_format(
      "<?xml version=\"1.0\"?>\n<feed xmlns=\"http://www.w3.org/2005/Atom\">",
    ),
    @detect.FeedFormat::Atom,
  )
  @test.assert_eq(
    @detect.detect_format("<!-- preface -->\n<rss version=\"2.0\">"),
    @detect.FeedFormat::Rss,
  )
}

///|
test "format detector accepts the declared atom prefix only" {
  @test.assert_eq(
    @detect.detect_format(
      "<atom:feed xmlns:atom=\"http://www.w3.org/2005/Atom\">",
    ),
    @detect.FeedFormat::Atom,
  )
  assert_true(
    format_error("<foo:feed xmlns:foo=\"http://www.w3.org/2005/Atom\">")
    is @detect.DetectError::UnknownFormat,
  )
  assert_true(format_error("<atom:feed>") is @detect.DetectError::UnknownFormat)
  assert_true(
    format_error("<feed xmlns=\"urn:not-atom\">")
    is @detect.DetectError::UnknownFormat,
  )
}

///|
test "format detector rejects unknown roots and JSON is only a candidate" {
  assert_true(
    format_error("<html><body/></html>") is @detect.DetectError::UnknownFormat,
  )
  assert_true(format_error("<feedish/>") is @detect.DetectError::UnknownFormat)
  assert_true(format_error("<rssLike/>") is @detect.DetectError::UnknownFormat)
  @test.assert_eq(
    @detect.detect_format("{\"foo\":\"bar\"}"),
    @detect.FeedFormat::JsonFeed,
  )
  assert_true(
    unified_error("{\"foo\":\"bar\"}")
    is @moonfeed.ParseError::JsonFeed(@jsonfeed.MissingField("$.version")),
  )
}

///|
test "format detector distinguishes empty input and malformed XML prefix" {
  assert_true(format_error("") is @detect.DetectError::EmptyInput)
  assert_true(format_error(" \r\n\t") is @detect.DetectError::EmptyInput)
  assert_true(format_error("<") is @detect.DetectError::MalformedPrefix(_))
  assert_true(
    format_error("<?xml version=\"1.0\"")
    is @detect.DetectError::MalformedPrefix(_),
  )
  assert_true(
    format_error("<!-- not closed") is @detect.DetectError::MalformedPrefix(_),
  )
  assert_true(format_error("plain text") is @detect.DetectError::UnknownFormat)
}

///|
test "unified parse dispatches JSON Feed RSS and Atom" {
  let json_feed = @moonfeed.parse(@samples.minimal)
  @test.assert_eq(json_feed.title, "MoonFeed")
  let rss = @moonfeed.parse(
    "<rss version=\"2.0\"><channel><title>R</title><link>home</link><description>D</description></channel></rss>",
  )
  @test.assert_eq(rss.title, "R")
  let atom = @moonfeed.parse(@atoms.minimal)
  @test.assert_eq(atom.title, "Minimal")
  let spaced_atom = @moonfeed.parse(" \n" + @atoms.minimal)
  @test.assert_eq(spaced_atom.title, "Minimal")
}

///|
test "unified parse preserves format-specific typed errors" {
  assert_true(
    unified_error("<html/>")
    is @moonfeed.ParseError::Detect(@detect.DetectError::UnknownFormat),
  )
  assert_true(
    unified_error("{\"version\":\"bad\"}")
    is @moonfeed.ParseError::JsonFeed(@jsonfeed.UnsupportedVersion("bad")),
  )
  assert_true(
    unified_error("<rss version=\"1.0\"/>")
    is @moonfeed.ParseError::Rss(@rss.UnsupportedRssVersion("1.0")),
  )
  assert_true(
    unified_error("<feed><id>f</id><title>T</title></feed>")
    is @moonfeed.ParseError::Atom(@atom.InvalidRequiredField("feed.updated", _)),
  )
}

///|
test "unified parse handles XML declaration and UTF-8 BOM" {
  let rss = "\u{FEFF} <?xml version=\"1.0\" encoding=\"UTF-8\"?><rss version=\"2.0\"><channel><title>R</title><link>home</link><description>D</description></channel></rss>"
  @test.assert_eq(@moonfeed.parse(rss).title, "R")
}
