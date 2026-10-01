///|
// RSS nodes are built from the internal XML event stream.
priv struct Node {
  name : String
  attributes : Map[String, String]
  children : Array[Node]
  text : StringBuilder
}

///|
fn node(element : @xmlmini.XmlElement) -> Node {
  {
    name: element.name,
    attributes: element.attributes,
    children: [],
    text: StringBuilder(),
  }
}

///|
fn document(input : String) -> Node raise ParseError {
  let reader = @xmlmini.Reader::from_string(input)
  let stack : Array[Node] = []
  let roots : Array[Node] = []
  while true {
    let event = reader.read_event() catch {
      _ => raise InvalidXml("malformed XML")
    }
    match event {
      Start(element) => {
        if stack.length() >= 256 {
          raise InvalidXml("element depth exceeds 256")
        }
        stack.push(node(element))
      }
      Empty(element) => {
        let element = node(element)
        if stack.is_empty() {
          roots.push(element)
        } else {
          stack[stack.length() - 1].children.push(element)
        }
      }
      End(_) => {
        guard stack.pop() is Some(element) else {
          raise InvalidXml("unexpected closing element")
        }
        if stack.is_empty() {
          roots.push(element)
        } else {
          stack[stack.length() - 1].children.push(element)
        }
      }
      Text(text) | CData(text) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(text)
        }
      Eof => break
    }
  }
  guard roots.length() == 1 && stack.is_empty() else {
    raise InvalidXml("expected one complete document element")
  }
  roots[0]
}

///|
fn children(parent : Node, name : String) -> Array[Node] {
  parent.children.filter(child => child.name == name)
}

///|
fn single(
  parent : Node,
  name : String,
  path : String,
) -> Node? raise ParseError {
  let matches = children(parent, name)
  if matches.length() > 1 {
    raise InvalidRequiredField(path + "." + name, "duplicate singleton element")
  }
  if matches.length() == 0 {
    None
  } else {
    Some(matches[0])
  }
}

///|
fn text(element : Node, path : String) -> String raise ParseError {
  if !element.children.is_empty() {
    raise InvalidRequiredField(
      path, "expected text or CDATA, not nested elements",
    )
  }
  element.text.to_string().trim(chars=" \t\r\n").to_owned()
}

///|
fn optional_text(
  parent : Node,
  name : String,
  path : String,
) -> String? raise ParseError {
  match single(parent, name, path) {
    Some(element) => Some(text(element, path + "." + name))
    None => None
  }
}

///|
fn required_text(
  parent : Node,
  name : String,
  path : String,
) -> String raise ParseError {
  match optional_text(parent, name, path) {
    Some(value) => value
    None => raise InvalidRequiredField(path + "." + name, "missing element")
  }
}

///|
fn attribute(
  element : Node,
  name : String,
  path : String,
) -> String raise ParseError {
  match element.attributes.get(name) {
    Some(value) if value.trim(chars=" \t\r\n").length() > 0 => value
    _ =>
      raise InvalidRequiredField(
        path + "." + name,
        "missing or empty attribute",
      )
  }
}

///|
fn unsigned(value : String, path : String) -> UInt64 raise ParseError {
  if value.is_empty() {
    raise InvalidRequiredField(path, "expected unsigned decimal integer")
  }
  for ch in value {
    if ch < '0' || ch > '9' {
      raise InvalidRequiredField(path, "expected unsigned decimal integer")
    }
  }
  @string.parse_uint64(value) catch {
    _ => raise InvalidRequiredField(path, "integer exceeds UInt64 range")
  }
}

///|
fn optional_unsigned(
  parent : Node,
  name : String,
  path : String,
) -> UInt64? raise ParseError {
  match optional_text(parent, name, path) {
    Some(value) => Some(unsigned(value, path + "." + name))
    None => None
  }
}

///|
fn categories(parent : Node, path : String) -> Array[Category] raise ParseError {
  let result = []
  for index, category in children(parent, "category") {
    result.push({
      value: text(category, path + ".category[\{index}]"),
      domain: category.attributes.get("domain"),
    })
  }
  result
}

///|
fn enclosure(parent : Node, path : String) -> Enclosure? raise ParseError {
  try {
    match single(parent, "enclosure", path) {
      None => None
      Some(element) => {
        let path = path + ".enclosure"
        if !element.children.is_empty() || text(element, path) != "" {
          raise InvalidRequiredField(path, "enclosure must be empty")
        }
        Some({
          url: attribute(element, "url", path),
          mime_type: attribute(element, "type", path),
          length: unsigned(attribute(element, "length", path), path + ".length"),
        })
      }
    }
  } catch {
    InvalidRequiredField(path, message) => raise InvalidEnclosure(path, message)
    error => raise error
  }
}

///|
fn parse_item(element : Node, path : String) -> Item raise ParseError {
  let title = optional_text(element, "title", path)
  let description = optional_text(element, "description", path)
  if title is None && description is None {
    raise InvalidRequiredField(
      path + ".title|description",
      "at least one must be present",
    )
  }
  let guid = match single(element, "guid", path) {
    None => None
    Some(element) => {
      let value = text(element, path + ".guid")
      if value.is_empty() {
        raise InvalidRequiredField(path + ".guid", "guid must not be empty")
      }
      let is_permalink = match element.attributes.get("isPermaLink") {
        None | Some("true") => true
        Some("false") => false
        _ =>
          raise InvalidRequiredField(
            path + ".guid.isPermaLink",
            "expected true or false",
          )
      }
      Some({ value, is_permalink, })
    }
  }
  let source = match single(element, "source", path) {
    None => None
    Some(element) =>
      Some({
        title: text(element, path + ".source"),
        url: attribute(element, "url", path + ".source"),
      })
  }
  {
    title,
    description,
    guid,
    source,
    link: optional_text(element, "link", path),
    author: optional_text(element, "author", path),
    categories: categories(element, path),
    comments: optional_text(element, "comments", path),
    enclosure: enclosure(element, path),
    pub_date: optional_text(element, "pubDate", path),
  }
}

///|
/// Parse RSS 2.0 core fields while preserving metadata not represented by Feed.
pub fn parse_raw(input : String) -> Channel raise ParseError {
  let root = document(input)
  if root.name != "rss" || root.attributes.get("xmlns") is Some(_) {
    raise InvalidRequiredField("rss", "expected unnamespaced rss root")
  }
  let version = root.attributes.get("version").unwrap_or("")
  if version != "2.0" {
    raise UnsupportedRssVersion(version)
  }
  let channel = match single(root, "channel", "rss") {
    Some(channel) => channel
    None => raise MissingChannel
  }
  let title = optional_text(channel, "title", "channel").unwrap_or_else(() => {
    raise MissingChannelTitle
  })
  let link = optional_text(channel, "link", "channel").unwrap_or_else(() => {
    raise MissingChannelLink
  })
  let description = optional_text(channel, "description", "channel").unwrap_or_else(() => {
      raise MissingChannelDescription
    },
  )
  let image = match single(channel, "image", "channel") {
    None => None
    Some(element) =>
      Some({
        url: required_text(element, "url", "channel.image"),
        title: required_text(element, "title", "channel.image"),
        link: required_text(element, "link", "channel.image"),
        width: optional_unsigned(element, "width", "channel.image"),
        height: optional_unsigned(element, "height", "channel.image"),
        description: optional_text(element, "description", "channel.image"),
      })
  }
  let items = []
  for index, item in children(channel, "item") {
    items.push(parse_item(item, "channel.item[\{index}]"))
  }
  {
    title,
    link,
    description,
    image,
    items,
    language: optional_text(channel, "language", "channel"),
    pub_date: optional_text(channel, "pubDate", "channel"),
    last_build_date: optional_text(channel, "lastBuildDate", "channel"),
    managing_editor: optional_text(channel, "managingEditor", "channel"),
    web_master: optional_text(channel, "webMaster", "channel"),
    categories: categories(channel, "channel"),
    generator: optional_text(channel, "generator", "channel"),
    docs: optional_text(channel, "docs", "channel"),
    ttl: optional_unsigned(channel, "ttl", "channel"),
  }
}
