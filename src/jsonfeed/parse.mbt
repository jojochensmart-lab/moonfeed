///|
/// Parsing is atomic: an invalid supported field rejects the entire feed.
pub(all) suberror ParseError {
  InvalidJson(String)
  MissingField(String)
  InvalidType(String, String)
  UnsupportedVersion(String)
  InvalidValue(String, String)
} derive(Eq, @debug.Debug)

///|
fn object(value : Json, path : String) -> Map[String, Json] raise ParseError {
  match value {
    Object(fields) => fields
    _ => raise InvalidType(path, "object")
  }
}

///|
fn required(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Json raise ParseError {
  match fields.get(key) {
    Some(value) => value
    None => raise MissingField(path + "." + key)
  }
}

///|
fn string(value : Json, path : String) -> String raise ParseError {
  match value {
    String(value) => value
    _ => raise InvalidType(path, "string")
  }
}

///|
fn required_string(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> String raise ParseError {
  string(required(fields, key, path), path + "." + key)
}

///|
fn optional_string(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> String? raise ParseError {
  match fields.get(key) {
    None => None
    Some(value) => Some(string(value, path + "." + key))
  }
}

///|
fn array(value : Json, path : String) -> Array[Json] raise ParseError {
  match value {
    Array(values) => values
    _ => raise InvalidType(path, "array")
  }
}

///|
fn authors(
  fields : Map[String, Json],
  path : String,
) -> Array[@model.Author]? raise ParseError {
  match fields.get("authors") {
    None => None
    Some(value) => {
      let result : Array[@model.Author] = []
      let values = array(value, path + ".authors")
      for index, entry in values {
        let author_path = path + ".authors[\{index}]"
        let entry = object(entry, author_path)
        let name = optional_string(entry, "name", author_path)
        let url = optional_string(entry, "url", author_path)
        let avatar = optional_string(entry, "avatar", author_path)
        if name is None && url is None && avatar is None {
          raise InvalidValue(author_path, "author needs name, url or avatar")
        }
        result.push({ name, url, avatar, })
      }
      Some(result)
    }
  }
}

///|
fn tags(
  fields : Map[String, Json],
  path : String,
) -> Array[String] raise ParseError {
  let result = []
  if fields.get("tags") is Some(value) {
    for index, tag in array(value, path + ".tags") {
      result.push(string(tag, path + ".tags[\{index}]"))
    }
  }
  result
}

///|
fn item(
  value : Json,
  path : String,
  feed_authors : Array[@model.Author],
  feed_language : String?,
) -> @model.FeedItem raise ParseError {
  let fields = object(value, path)
  let id = required_string(fields, "id", path)
  let published = optional_string(fields, "date_published", path)
  let updated = optional_string(fields, "date_modified", path)
  let published_at = @datetime.parse_optional_datetime(published)
  let updated_at = @datetime.parse_optional_datetime(updated)
  if id == "" {
    raise InvalidValue(path + ".id", "id must not be empty")
  }
  let content_text = optional_string(fields, "content_text", path)
  let content_html = optional_string(fields, "content_html", path)
  if content_text is None && content_html is None {
    raise MissingField(path + ".content_text|content_html")
  }
  let item_authors = match authors(fields, path) {
    Some(value) => value
    None => feed_authors.copy()
  }
  let language = match optional_string(fields, "language", path) {
    Some(value) => Some(value)
    None => feed_language
  }
  {
    id,
    title: optional_string(fields, "title", path),
    url: optional_string(fields, "url", path),
    external_url: optional_string(fields, "external_url", path),
    authors: item_authors,
    summary: optional_string(fields, "summary", path),
    content_text,
    content_html,
    published,
    published_at,
    updated,
    updated_at,
    language,
    categories: tags(fields, path),
    attachments: [],
  }
}

///|
/// Decode JSON Feed 1.1 into the unified model. No network or filesystem access.
/// Unsupported fields are ignored. Date strings are preserved and parsed best-effort; URLs are retained without validation.
pub fn parse(input : String) -> @model.Feed raise ParseError {
  let value = @json.parse(input) catch {
    error => raise InvalidJson(error.to_string())
  }
  let fields = object(value, "$")
  let version = required_string(fields, "version", "$")
  if version != "https://jsonfeed.org/version/1.1" {
    raise UnsupportedVersion(version)
  }
  let title = required_string(fields, "title", "$")
  let feed_authors = authors(fields, "$").unwrap_or([])
  let language = optional_string(fields, "language", "$")
  let items = []
  let ids : Map[String, Bool] = Map([])
  for index, value in array(required(fields, "items", "$"), "$.items") {
    let path = "$.items[\{index}]"
    let parsed = item(value, path, feed_authors, language)
    if ids.contains(parsed.id) {
      raise InvalidValue(path + ".id", "duplicate item id")
    }
    ids.set(parsed.id, true)
    items.push(parsed)
  }
  {
    title,
    description: optional_string(fields, "description", "$"),
    home_page_url: optional_string(fields, "home_page_url", "$"),
    feed_url: optional_string(fields, "feed_url", "$"),
    language,
    authors: feed_authors,
    categories: [],
    updated: None,
    updated_at: None,
    items,
  }
}
