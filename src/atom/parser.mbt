///|
pub(all) suberror ParseError {
  InvalidXml(String)
  InvalidAtomRoot(String)
  InvalidRequiredField(String, String)
} derive(Eq, @debug.Debug)

///|
pub fn ParseError::equal(self : ParseError, other : ParseError) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn ParseError::not_equal(self : ParseError, other : ParseError) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn ParseError::to_repr(self : ParseError) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
priv enum NodeContent {
  PartText(String)
  PartElement(Node)
}

///|
priv struct Node {
  name : String
  attributes : Map[String, String]
  children : Array[Node]
  content : Array[NodeContent]
  text : StringBuilder
}

///|
fn make_node(element : @xmlmini.XmlElement) -> Node {
  {
    name: element.name,
    attributes: element.attributes,
    children: [],
    content: [],
    text: StringBuilder(),
  }
}

///|
fn local_name(name : String) -> String {
  if name.has_prefix("atom:") {
    name[5:].to_owned()
  } else {
    name
  }
}

///|
fn is_atom_name(name : String) -> Bool {
  !name.contains(":") || name.has_prefix("atom:")
}

///|
fn named(node : Node, name : String) -> Bool {
  is_atom_name(node.name) && local_name(node.name) == name
}

///|
fn atom_children(parent : Node, name : String) -> Array[Node] {
  parent.children.filter(child => named(child, name))
}

///|
fn doc(input : String) -> Node raise ParseError {
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
        stack.push(make_node(element))
      }
      Empty(element) => {
        let child = make_node(element)
        if stack.is_empty() {
          roots.push(child)
        } else {
          stack[stack.length() - 1].children.push(child)
          stack[stack.length() - 1].content.push(PartElement(child))
        }
      }
      End(_) => {
        guard stack.pop() is Some(child) else {
          raise InvalidXml("unexpected closing element")
        }
        if stack.is_empty() {
          roots.push(child)
        } else {
          stack[stack.length() - 1].children.push(child)
          stack[stack.length() - 1].content.push(PartElement(child))
        }
      }
      Text(value) | CData(value) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(value)
          stack[stack.length() - 1].content.push(PartText(value))
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
fn one(parent : Node, name : String, path : String) -> Node? raise ParseError {
  let matches = atom_children(parent, name)
  if matches.length() > 1 {
    raise InvalidRequiredField(path + "." + name, "duplicate element")
  }
  if matches.is_empty() {
    None
  } else {
    Some(matches[0])
  }
}

///|
fn plain_text(node : Node) -> String {
  let out = StringBuilder()
  for part in node.content {
    match part {
      PartText(value) => out.write_string(value)
      PartElement(child) => out.write_string(plain_text(child))
    }
  }
  out.to_string().trim(chars=" \t\r\n").to_owned()
}

///|
fn optional_text(
  parent : Node,
  name : String,
  path : String,
) -> String? raise ParseError {
  match one(parent, name, path) {
    Some(node) => Some(plain_text(node))
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
    Some(value) if !value.is_empty() => value
    _ =>
      raise InvalidRequiredField(path + "." + name, "missing or empty element")
  }
}

///|
fn attr(node : Node, key : String, path : String) -> String raise ParseError {
  match node.attributes.get(key) {
    Some(value) if !value.trim(chars=" \t\r\n").is_empty() => value
    _ =>
      raise InvalidRequiredField(path + "." + key, "missing or empty attribute")
  }
}

///|
fn optional_attr(node : Node, key : String) -> String? {
  match node.attributes.get(key) {
    Some(value) if !value.trim(chars=" \t\r\n").is_empty() => Some(value)
    _ => None
  }
}

///|
fn text_construct(node : Node) -> String {
  let kind = node.attributes.get("type").unwrap_or("text")
  if kind == "xhtml" {
    plain_text(node)
  } else {
    node.text.to_string().trim(chars=" \t\r\n").to_owned()
  }
}

///|
fn construct(
  parent : Node,
  name : String,
  path : String,
) -> String? raise ParseError {
  match one(parent, name, path) {
    Some(node) => Some(text_construct(node))
    None => None
  }
}

///|
fn persons(parent : Node, name : String) -> Array[@model.Author] {
  let result : Array[@model.Author] = []
  for person in atom_children(parent, name) {
    let author : @model.Author = {
      name: match atom_children(person, "name") {
        [n, ..] => Some(plain_text(n))
        _ => None
      },
      url: match atom_children(person, "uri") {
        [n, ..] => Some(plain_text(n))
        _ => None
      },
      avatar: None,
    }
    result.push(author)
  }
  result
}

///|
fn categories(parent : Node, path : String) -> Array[String] raise ParseError {
  let result = []
  for index, category in atom_children(parent, "category") {
    result.push(attr(category, "term", path + ".category[\{index}]"))
  }
  result
}

///|
fn link_values(
  parent : Node,
  path : String,
) -> (String?, String?, Array[@model.Attachment]) raise ParseError {
  let mut alternate = None
  let mut self_url = None
  let attachments : Array[@model.Attachment] = []
  for index, link in atom_children(parent, "link") {
    let link_path = path + ".link[\{index}]"
    let href = attr(link, "href", link_path)
    let rel = link.attributes.get("rel").unwrap_or("alternate")
    match rel {
      "alternate" => if alternate is None { alternate = Some(href) }
      "self" => if self_url is None { self_url = Some(href) }
      "enclosure" =>
        attachments.push({
          url: href,
          mime_type: optional_attr(link, "type").unwrap_or(
            "application/octet-stream",
          ),
          title: optional_attr(link, "title"),
          size_in_bytes: match optional_attr(link, "length") {
            Some(value) =>
              Some(
                @string.parse_uint64(value) catch {
                  _ =>
                    raise InvalidRequiredField(
                      link_path + ".length",
                      "expected unsigned integer",
                    )
                },
              )
            None => None
          },
          duration_in_seconds: None,
        })
      _ => ()
    }
  }
  (alternate, self_url, attachments)
}

///|
fn entry(
  node : Node,
  index : Int,
  feed_authors : Array[@model.Author],
) -> @model.FeedItem raise ParseError {
  let path = "feed.entry[\{index}]"
  let id = required_text(node, "id", path)
  let title = construct(node, "title", path)
  if title is None || title.unwrap().is_empty() {
    raise InvalidRequiredField(path + ".title", "missing or empty element")
  }
  let updated = required_text(node, "updated", path)
  let (url, _, attachments) = link_values(node, path)
  let authors = persons(node, "author")
  let summary = construct(node, "summary", path)
  let content = construct(node, "content", path)
  let content_kind = match one(node, "content", path) {
    Some(c) => c.attributes.get("type").unwrap_or("text")
    _ => ""
  }
  {
    id,
    title,
    url,
    external_url: None,
    authors: if authors.is_empty() {
      feed_authors
    } else {
      authors
    },
    summary,
    content_text: if content_kind == "text" {
      content
    } else {
      None
    },
    content_html: if content_kind == "html" || content_kind == "xhtml" {
      content
    } else {
      None
    },
    published: optional_text(node, "published", path),
    updated: Some(updated),
    language: None,
    categories: categories(node, path),
    attachments,
  }
}

///|
/// Parse and normalize an Atom 1.0 feed. Date values remain unchanged strings.
pub fn parse(input : String) -> @model.Feed raise ParseError {
  let root = doc(input)
  if !named(root, "feed") {
    raise InvalidAtomRoot(root.name)
  }
  let _feed_id = required_text(root, "id", "feed")
  let title = construct(root, "title", "feed")
  if title is None || title.unwrap().is_empty() {
    raise InvalidRequiredField("feed.title", "missing or empty element")
  }
  let updated = required_text(root, "updated", "feed")
  let authors = persons(root, "author")
  let (home_page_url, feed_url, _) = link_values(root, "feed")
  let entries = []
  for index, item in atom_children(root, "entry") {
    entries.push(entry(item, index, authors))
  }
  {
    title: title.unwrap(),
    description: construct(root, "subtitle", "feed"),
    home_page_url,
    feed_url,
    language: optional_attr(root, "xml:lang"),
    authors,
    categories: categories(root, "feed"),
    updated: Some(updated),
    items: entries,
  }
}
