///|
fn category_values(categories : Array[Category]) -> Array[String] {
  let result = []
  for category in categories {
    result.push(category.value)
  }
  result
}

///|
fn item_authors(author : String?) -> Array[@model.Author] {
  match author {
    Some(value) => [{ name: Some(value), url: None, avatar: None, }]
    None => []
  }
}

///|
fn item_id(item : Item, path : String) -> String raise ParseError {
  match item.guid {
    Some(guid) => guid.value
    None =>
      match item.link {
        Some(link) if !link.is_empty() => link
        _ =>
          raise InvalidRequiredField(
            path + ".id",
            "guid or link is required for a stable item identity",
          )
      }
  }
}

///|
fn attachment(enclosure : Enclosure) -> @model.Attachment {
  {
    url: enclosure.url,
    mime_type: enclosure.mime_type,
    title: None,
    size_in_bytes: Some(enclosure.length),
    duration_in_seconds: None,
  }
}

///|
fn normalize_item(item : Item, index : Int) -> @model.FeedItem raise ParseError {
  let path = "channel.item[\{index}]"
  let description = item.description
  {
    id: item_id(item, path),
    title: item.title,
    url: item.link,
    external_url: None,
    authors: item_authors(item.author),
    summary: description,
    content_text: None,
    content_html: description,
    published: item.pub_date,
    updated: None,
    language: None,
    categories: category_values(item.categories),
    attachments: match item.enclosure {
      Some(value) => [attachment(value)]
      None => []
    },
  }
}

///|
/// Convert an RSS 2.0 channel to the shared Feed model.
/// RSS descriptions are retained as both the item summary and HTML content because
/// RSS does not declare whether description text contains markup.
pub fn normalize(channel : Channel) -> @model.Feed raise ParseError {
  let updated = match channel.last_build_date {
    Some(value) => Some(value)
    None => channel.pub_date
  }
  let items = []
  for index, item in channel.items {
    items.push(normalize_item(item, index))
  }
  {
    title: channel.title,
    description: Some(channel.description),
    home_page_url: Some(channel.link),
    feed_url: None,
    language: channel.language,
    authors: match channel.managing_editor {
      Some(value) => [{ name: Some(value), url: None, avatar: None, }]
      None => []
    },
    categories: category_values(channel.categories),
    updated,
    items,
  }
}

///|
/// Parse and normalize an RSS 2.0 document in one operation.
pub fn parse(input : String) -> @model.Feed raise ParseError {
  normalize(parse_raw(input))
}
