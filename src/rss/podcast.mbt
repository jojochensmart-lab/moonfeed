///|
fn podcast_extension_enabled(root : Node, channel : Node) -> Bool {
  let uri = "http://www.itunes.com/dtds/podcast-1.0.dtd"
  root.attributes.get("xmlns:itunes") == Some(uri) ||
  channel.attributes.get("xmlns:itunes") == Some(uri)
}

///|
fn first_named(parent : Node, name : String) -> Node? {
  match children(parent, name) {
    [first, ..] => Some(first)
    _ => None
  }
}

///|
fn child_text(
  parent : Node,
  name : String,
  path : String,
) -> String? raise ParseError {
  match first_named(parent, name) {
    Some(element) => Some(text(element, path + "." + name))
    None => None
  }
}

///|
fn extension_bool(value : String, path : String) -> Bool raise ParseError {
  match value {
    "true" | "yes" => true
    "false" | "no" | "clean" => false
    _ =>
      raise InvalidRequiredField(
        path, "expected yes, no, true, false, or clean",
      )
  }
}

///|
fn optional_extension_bool(
  parent : Node,
  name : String,
  path : String,
) -> Bool? raise ParseError {
  match child_text(parent, name, path) {
    Some(value) => Some(extension_bool(value, path + "." + name))
    None => None
  }
}

///|
/// Parse Apple's HH:MM:SS, MM:SS, or SS duration forms.
fn podcast_duration(value : String, path : String) -> Double raise ParseError {
  let parts : Array[String] = []
  let mut part = StringBuilder()
  for ch in value.to_array() {
    if ch == ':' {
      if part.to_string().is_empty() {
        raise InvalidRequiredField(path, "duration contains an empty component")
      }
      parts.push(part.to_string())
      part = StringBuilder()
    } else if ch >= '0' && ch <= '9' {
      part.write_char(ch)
    } else {
      raise InvalidRequiredField(
        path, "duration must contain decimal components",
      )
    }
  }
  if part.to_string().is_empty() {
    raise InvalidRequiredField(path, "duration contains an empty component")
  }
  parts.push(part.to_string())
  if parts.length() > 3 {
    raise InvalidRequiredField(
      path, "duration must have at most three components",
    )
  }
  let values : Array[UInt64] = []
  for component in parts {
    values.push(
      @string.parse_uint64(component) catch {
        _ =>
          raise InvalidRequiredField(path, "duration component exceeds UInt64")
      },
    )
  }
  let seconds = values[values.length() - 1]
  if seconds > 59UL && values.length() > 1 {
    raise InvalidRequiredField(path, "seconds component must be at most 59")
  }
  if values.length() == 1 {
    seconds.to_double()
  } else if values.length() == 2 {
    values[0].to_double() * 60.0 + seconds.to_double()
  } else {
    let minutes = values[1]
    if minutes > 59UL {
      raise InvalidRequiredField(path, "minutes component must be at most 59")
    }
    values[0].to_double() * 3600.0 +
    minutes.to_double() * 60.0 +
    seconds.to_double()
  }
}

///|
fn podcast_categories(
  channel : Node,
) -> Array[@model.PodcastCategory] raise ParseError {
  let result : Array[@model.PodcastCategory] = []
  for index, category in children(channel, "itunes:category") {
    let path = "channel.itunes:category[\{index}]"
    let name = category.attributes
      .get("text")
      .unwrap_or("")
      .trim(chars=" \t\r\n")
      .to_owned()
    if name.is_empty() {
      raise InvalidRequiredField(
        path + ".text",
        "missing or empty category text",
      )
    }
    let subcategories : Array[String] = []
    for child in children(category, "itunes:category") {
      let value = child.attributes
        .get("text")
        .unwrap_or("")
        .trim(chars=" \t\r\n")
        .to_owned()
      if value.is_empty() {
        raise InvalidRequiredField(
          path + ".itunes:category.text",
          "missing or empty subcategory text",
        )
      }
      subcategories.push(value)
    }
    result.push({ name, subcategories, })
  }
  result
}

///|
fn podcast_show_metadata(
  channel : Node,
  enabled : Bool,
) -> @model.PodcastShowMetadata raise ParseError {
  if !enabled {
    return {
      author: None,
      owner_name: None,
      owner_email: None,
      subtitle: None,
      summary: None,
      explicit: None,
      image_url: None,
      categories: [],
      podcast_type: None,
      complete: None,
      new_feed_url: None,
    }
  }
  let owner = first_named(channel, "itunes:owner")
  let image = first_named(channel, "itunes:image")
  {
    author: child_text(channel, "itunes:author", "channel"),
    owner_name: match owner {
      Some(value) => child_text(value, "itunes:name", "channel.itunes:owner")
      None => None
    },
    owner_email: match owner {
      Some(value) => child_text(value, "itunes:email", "channel.itunes:owner")
      None => None
    },
    subtitle: child_text(channel, "itunes:subtitle", "channel"),
    summary: child_text(channel, "itunes:summary", "channel"),
    explicit: optional_extension_bool(channel, "itunes:explicit", "channel"),
    image_url: match image {
      Some(value) => value.attributes.get("href")
      None => None
    },
    categories: podcast_categories(channel),
    podcast_type: child_text(channel, "itunes:type", "channel"),
    complete: optional_extension_bool(channel, "itunes:complete", "channel"),
    new_feed_url: child_text(channel, "itunes:new-feed-url", "channel"),
  }
}

///|
fn podcast_episode_metadata(
  item : Node,
  index : Int,
  enabled : Bool,
) -> @model.PodcastEpisodeMetadata raise ParseError {
  if !enabled {
    return {
      subtitle: None,
      summary: None,
      image_url: None,
      duration_in_seconds: None,
      episode_number: None,
      season_number: None,
      episode_type: None,
      explicit: None,
      block: None,
    }
  }
  let path = "channel.item[\{index}]"
  let image = first_named(item, "itunes:image")
  {
    subtitle: child_text(item, "itunes:subtitle", path),
    summary: child_text(item, "itunes:summary", path),
    image_url: match image {
      Some(value) => value.attributes.get("href")
      None => None
    },
    duration_in_seconds: match child_text(item, "itunes:duration", path) {
      Some(value) => Some(podcast_duration(value, path + ".itunes:duration"))
      None => None
    },
    episode_number: optional_unsigned(item, "itunes:episode", path),
    season_number: optional_unsigned(item, "itunes:season", path),
    episode_type: child_text(item, "itunes:episodeType", path),
    explicit: optional_extension_bool(item, "itunes:explicit", path),
    block: optional_extension_bool(item, "itunes:block", path),
  }
}

///|
fn feed_with_podcast_durations(
  feed : @model.Feed,
  episodes : Array[@model.PodcastEpisodeMetadata],
) -> @model.Feed {
  let items : Array[@model.FeedItem] = []
  for index, item in feed.items {
    let attachments : Array[@model.Attachment] = []
    for attachment in item.attachments {
      let duration = if index < episodes.length() {
        episodes[index].duration_in_seconds
      } else {
        None
      }
      attachments.push({
        url: attachment.url,
        mime_type: attachment.mime_type,
        title: attachment.title,
        size_in_bytes: attachment.size_in_bytes,
        duration_in_seconds: duration,
      })
    }
    items.push({
      id: item.id,
      title: item.title,
      url: item.url,
      external_url: item.external_url,
      authors: item.authors,
      summary: item.summary,
      content_text: item.content_text,
      content_html: item.content_html,
      published: item.published,
      published_at: item.published_at,
      updated: item.updated,
      updated_at: item.updated_at,
      language: item.language,
      categories: item.categories,
      attachments,
    })
  }
  {
    title: feed.title,
    description: feed.description,
    home_page_url: feed.home_page_url,
    feed_url: feed.feed_url,
    language: feed.language,
    authors: feed.authors,
    categories: feed.categories,
    updated: feed.updated,
    updated_at: feed.updated_at,
    items,
  }
}

///|
/// Parse RSS 2.0 plus the Apple Podcasts/iTunes RSS extension metadata.
/// Only the literal `itunes:` prefix and the canonical extension URI are recognized.
pub fn parse_podcast(input : String) -> @model.PodcastFeed raise ParseError {
  let root = document(input)
  let raw = parse_channel(root)
  let channel = match single(root, "channel", "rss") {
    Some(value) => value
    None => raise MissingChannel
  }
  let enabled = podcast_extension_enabled(root, channel)
  let show = podcast_show_metadata(channel, enabled)
  let episodes : Array[@model.PodcastEpisodeMetadata] = []
  for index, item in children(channel, "item") {
    episodes.push(podcast_episode_metadata(item, index, enabled))
  }
  let feed = feed_with_podcast_durations(normalize(raw), episodes)
  { feed, show, episodes, }
}
