///|
/// Parse and normalize an RSS 2.0 feed into the unified model.
pub fn parse_rss(input : String) -> @model.Feed raise @rss.ParseError {
  @rss.parse(input)
}
