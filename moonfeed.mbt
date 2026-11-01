///|
/// Common result types can be named without importing internal packages.
pub using @model {
  type Feed,
  type FeedItem,
  type Author,
  type Attachment,
  type FeedLink,
  type PodcastFeed,
  type PodcastShowMetadata,
  type PodcastEpisodeMetadata,
  type PodcastCategory,
}

///|
/// Parse supported JSON Feed 1.1 fields into the unified Feed model.
pub fn parse_json_feed(
  input : String,
) -> @model.Feed raise @jsonfeed.ParseError {
  @jsonfeed.parse(input)
}
