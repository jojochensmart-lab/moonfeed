///|
pub(all) suberror ParseError {
  InvalidXml(String)
  InvalidAtomRoot(String)
  InvalidRequiredField(String, String)
  InvalidDateTime(String, @datetime.DateTimeError)
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
  name : @xmlmini.ExpandedName
  attributes : Array[@xmlmini.NamespaceAttribute]
  language : String?
  base_uri : String?
  children : Array[Node]
  content : Array[NodeContent]
  text : StringBuilder
}

///|
fn make_node(
  element : @xmlmini.NamespaceElement,
  inherited_language : String?,
  inherited_base : String?,
) -> Node raise ParseError {
  let language_attribute = namespace_attribute(
    element, "http://www.w3.org/XML/1998/namespace", "lang",
  )
  let language = match language_attribute {
    Some(value) if value.is_empty() => None
    Some(value) => Some(value)
    None => inherited_language
  }
  let base_attribute = namespace_attribute(
    element, "http://www.w3.org/XML/1998/namespace", "base",
  )
  let base_uri = match base_attribute {
    Some(reference) =>
      Some(resolve_xml_base(inherited_base, reference).resolved) catch {
        _ =>
          raise InvalidRequiredField("xml:base", "invalid XML Base reference")
      }
    None => inherited_base
  }
  {
    name: element.name,
    attributes: element.attributes,
    language,
    base_uri,
    children: [],
    content: [],
    text: StringBuilder(),
  }
}

///|
fn named(node : Node, name : String) -> Bool {
  node.name.namespace_uri == Some("http://www.w3.org/2005/Atom") &&
  node.name.local_name == name
}

///|
fn atom_children(parent : Node, name : String) -> Array[Node] {
  parent.children.filter(child => named(child, name))
}

///|
fn doc(input : String) -> Node raise ParseError {
  document_tree(input, None)
}

///|
fn document_tree(
  input : String,
  document_uri : String?,
  strict_declaration? : Bool = false,
) -> Node raise ParseError {
  let normalized = if input.has_prefix("\u{FEFF}") {
    input[1:].to_owned()
  } else {
    input
  }
  let reader = @xmlmini.NamespaceReader::from_string(
    normalized,
    strict_declaration~,
  )
  let stack : Array[Node] = []
  let roots : Array[Node] = []
  while true {
    let event = reader.read_event() catch {
      _ => raise InvalidXml("malformed XML")
    }
    match event {
      @xmlmini.NamespaceStart(element) => {
        if stack.length() >= 256 {
          raise InvalidXml("element depth exceeds 256")
        }
        let inherited_language = if stack.is_empty() {
          None
        } else {
          stack[stack.length() - 1].language
        }
        let inherited_base = if stack.is_empty() {
          document_uri
        } else {
          stack[stack.length() - 1].base_uri
        }
        stack.push(make_node(element, inherited_language, inherited_base))
      }
      @xmlmini.NamespaceEmpty(element) => {
        let inherited_language = if stack.is_empty() {
          None
        } else {
          stack[stack.length() - 1].language
        }
        let inherited_base = if stack.is_empty() {
          document_uri
        } else {
          stack[stack.length() - 1].base_uri
        }
        let child = make_node(element, inherited_language, inherited_base)
        if stack.is_empty() {
          roots.push(child)
        } else {
          stack[stack.length() - 1].children.push(child)
          stack[stack.length() - 1].content.push(PartElement(child))
        }
      }
      @xmlmini.NamespaceEnd(_) => {
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
      @xmlmini.NamespaceText(value) | @xmlmini.NamespaceCData(value) =>
        if !stack.is_empty() {
          stack[stack.length() - 1].text.write_string(value)
          stack[stack.length() - 1].content.push(PartText(value))
        } else if !value.trim(chars=" \t\r\n").is_empty() ||
          event is @xmlmini.NamespaceCData(_) {
          raise InvalidXml("character data outside document element")
        }
      @xmlmini.NamespaceEof => break
    }
  }
  guard roots.length() == 1 && stack.is_empty() else {
    raise InvalidXml("expected one complete document element")
  }
  roots[0]
}

///|
fn namespace_attribute(
  element : @xmlmini.NamespaceElement,
  namespace_uri : String,
  local_name : String,
) -> String? {
  for attribute in element.attributes {
    if attribute.name.namespace_uri == Some(namespace_uri) &&
      attribute.name.local_name == local_name {
      return Some(attribute.value)
    }
  }
  None
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
  match optional_attr(node, key) {
    Some(value) if !value.trim(chars=" \t\r\n").is_empty() => value
    _ =>
      raise InvalidRequiredField(path + "." + key, "missing or empty attribute")
  }
}

///|
fn optional_attr(node : Node, key : String) -> String? {
  for attribute in node.attributes {
    if attribute.name.namespace_uri is None && attribute.name.local_name == key {
      return if !attribute.value.trim(chars=" \t\r\n").is_empty() {
        Some(attribute.value)
      } else {
        None
      }
    }
  }
  None
}

///|
fn text_construct(node : Node) -> String {
  let kind = optional_attr(node, "type").unwrap_or("text")
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
    let href = reference(
        link,
        attr(link, "href", link_path),
        link_path + ".href",
      ).resolved
    let rel = optional_attr(link, "rel").unwrap_or("alternate")
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
  let updated_at = @datetime.parse_datetime(updated) catch {
    error => raise InvalidDateTime(path + ".updated", error)
  }
  let published = optional_text(node, "published", path)
  let published_at = @datetime.parse_optional_datetime(published)
  let (url, _, attachments) = link_values(node, path)
  let authors = persons(node, "author")
  let summary = construct(node, "summary", path)
  let content = construct(node, "content", path)
  let content_kind = match one(node, "content", path) {
    Some(c) => optional_attr(c, "type").unwrap_or("text")
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
    published,
    published_at,
    updated: Some(updated),
    updated_at: Some(updated_at),
    language: node.language,
    categories: categories(node, path),
    attachments,
  }
}

///|
/// Parse and normalize an Atom 1.0 feed. Original date strings remain available; successfully parsed dates also carry normalized UTC instants. Invalid required updated dates return typed errors.
pub fn parse(input : String) -> @model.Feed raise ParseError {
  let root = doc(input)
  if !named(root, "feed") {
    raise InvalidAtomRoot(root.name.local_name)
  }
  let _feed_id = required_text(root, "id", "feed")
  let title = construct(root, "title", "feed")
  if title is None || title.unwrap().is_empty() {
    raise InvalidRequiredField("feed.title", "missing or empty element")
  }
  let updated = required_text(root, "updated", "feed")
  let updated_at = @datetime.parse_datetime(updated) catch {
    error => raise InvalidDateTime("feed.updated", error)
  }
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
    language: root.language,
    authors,
    categories: categories(root, "feed"),
    updated: Some(updated),
    updated_at: Some(updated_at),
    items: entries,
  }
}
