///|
/// A podcast category from an iTunes-style RSS extension.
pub(all) struct PodcastCategory {
  name : String
  subcategories : Array[String]
}

///|
/// Podcast-level extension metadata kept separate from the format-neutral Feed.
pub(all) struct PodcastShowMetadata {
  author : String?
  owner_name : String?
  owner_email : String?
  subtitle : String?
  summary : String?
  explicit : Bool?
  image_url : String?
  categories : Array[PodcastCategory]
  podcast_type : String?
  complete : Bool?
  new_feed_url : String?
}

///|
/// Podcast episode extensions. Duration is also reflected in its enclosure attachment.
pub(all) struct PodcastEpisodeMetadata {
  subtitle : String?
  summary : String?
  image_url : String?
  duration_in_seconds : Double?
  episode_number : UInt64?
  season_number : UInt64?
  episode_type : String?
  explicit : Bool?
  block : Bool?
}

///|
/// RSS content plus podcast-only metadata that has no slot in the common Feed model.
pub(all) struct PodcastFeed {
  feed : Feed
  show : PodcastShowMetadata
  episodes : Array[PodcastEpisodeMetadata]
}
