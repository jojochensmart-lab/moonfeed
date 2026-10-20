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
