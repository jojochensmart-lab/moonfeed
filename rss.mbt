///|
/// Parse and normalize an RSS 2.0 feed into the unified model.
pub fn parse_rss(input : String) -> @model.Feed raise @rss.ParseError {
  @rss.parse(input)
}

///|
/// Parse an RSS podcast and retain Apple Podcasts extension metadata.
pub fn parse_podcast_rss(
  input : String,
) -> @model.PodcastFeed raise @rss.ParseError {
  @rss.parse_podcast(input)
}

///|
/// Detect whether the input is JSON Feed, RSS, or Atom.
pub fn detect_format(
  input : String,
) -> @detect.FeedFormat raise @detect.DetectError {
  @detect.detect_format(strip_utf8_bom(input))
}
