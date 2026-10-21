///|
fn markup(node : Node) -> Markup {
  let attributes = node.attributes.map(a => MarkupAttribute::{
    namespace_uri: a.name.namespace_uri,
    local_name: a.name.local_name,
    value: a.value,
  })
  let content = node.content.map(part => {
    match part {
      PartText(value) => MarkupContent::Text(value)
      PartElement(child) => MarkupContent::Element(markup(child))
    }
  })
  {
    namespace_uri: node.name.namespace_uri,
    local_name: node.name.local_name,
    attributes,
    content,
    base_uri: node.base_uri,
    language: node.language,
  }
}

///|
fn raw_attr(node : Node, key : String) -> String? {
  for a in node.attributes {
    if a.name.namespace_uri is None && a.name.local_name == key {
      return Some(a.value)
    }
  }
  None
}

///|
fn needed_attr(
  node : Node,
  key : String,
  path : String,
) -> String raise ParseError {
  match raw_attr(node, key) {
    Some(value) => value
    None => raise InvalidRequiredField(path + "." + key, "missing attribute")
  }
}

///|
fn scalar(node : Node, path : String) -> String raise ParseError {
  if !node.children.is_empty() {
    raise InvalidRequiredField(path, "child elements are not allowed")
  }
  node.text.to_string()
}

///|
fn descendant_text(node : Node) -> String {
  let out = StringBuilder()
  for part in node.content {
    match part {
      PartText(s) => out.write_string(s)
      PartElement(child) => out.write_string(descendant_text(child))
    }
  }
  out.to_string()
}

///|
fn required_node(
  parent : Node,
  name : String,
  path : String,
) -> Node raise ParseError {
  match one(parent, name, path) {
    Some(node) => node
    None => raise InvalidRequiredField(path + "." + name, "missing element")
  }
}

///|
fn reference(
  node : Node,
  value : String,
  path : String,
) -> IriReference raise ParseError {
  resolve_reference(node.base_uri, value) catch {
    _ => raise InvalidRequiredField(path, "invalid IRI reference")
  }
}

///|
fn absolute_iri(value : String, path : String) -> String raise ParseError {
  let parsed = iri_parts(value) catch {
    _ => raise InvalidRequiredField(path, "invalid absolute IRI")
  }
  if parsed.scheme is None {
    raise InvalidRequiredField(path, "absolute IRI required")
  }
  // IDs are not base-resolved, case-folded, percent-decoded or normalized.
  value
}

///|
fn date_value(node : Node, path : String) -> AtomDate raise ParseError {
  let value = scalar(node, path)
  let a = value.to_array()
  if a.length() < 20 || a[10] != 'T' || value.contains("z") {
    raise InvalidRequiredField(
      path, "Atom dates require uppercase T/Z and RFC 3339 syntax",
    )
  }
  atom_date(value, path)
}

///|
fn xhtml_div(node : Node, path : String) -> Node raise ParseError {
  if node.children.length() != 1 ||
    !node.text.to_string().trim(chars=" \t\r\n").is_empty() {
    raise InvalidRequiredField(path, "expected one XHTML div")
  }
  let div = node.children[0]
  if div.name.namespace_uri != Some("http://www.w3.org/1999/xhtml") ||
    div.name.local_name != "div" {
    raise InvalidRequiredField(path, "expected XHTML namespace div")
  }
  div
}

///|
fn strict_text(node : Node, path : String) -> AtomText raise ParseError {
  let kind = raw_attr(node, "type").unwrap_or("text")
  let (value, xhtml) = match kind {
    "text" | "html" => (scalar(node, path), None)
    "xhtml" => {
      let div = xhtml_div(node, path)
      (descendant_text(div), Some(markup(div)))
    }
    _ =>
      raise InvalidRequiredField(
        path + ".type",
        "text construct type must be text, html or xhtml",
      )
  }
  { kind, value, xhtml, language: node.language, base_uri: node.base_uri, }
}

///|
fn optional_construct(
  parent : Node,
  name : String,
  path : String,
) -> AtomText? raise ParseError {
  match one(parent, name, path) {
    Some(node) => Some(strict_text(node, path + "." + name))
    None => None
  }
}

///|
fn media_type(value : String, path : String) -> String raise ParseError {
  parse_media_type(value, path).essence
}

///|
fn strict_person(node : Node, path : String) -> AtomPerson raise ParseError {
  container_structure(node, "person", path)
  let name = scalar(required_node(node, "name", path), path + ".name")
  let uri = match one(node, "uri", path) {
    Some(n) => Some(reference(n, scalar(n, path + ".uri"), path + ".uri"))
    None => None
  }
  let email = match one(node, "email", path) {
    Some(n) => {
      let value = scalar(n, path + ".email")
      validate_email(value, path + ".email")
      Some(value)
    }
    None => None
  }
  { name, uri, email, raw: markup(node), }
}

///|
fn strict_people(
  node : Node,
  name : String,
  path : String,
) -> Array[AtomPerson] raise ParseError {
  let result = []
  for i, person in atom_children(node, name) {
    result.push(strict_person(person, path + "." + name + "[\{i}]"))
  }
  result
}

///|
fn is_alternate(rel : String) -> Bool {
  rel == "alternate" ||
  rel == "http://www.iana.org/assignments/relation/alternate"
}

///|
fn strict_links(node : Node, path : String) -> Array[AtomLink] raise ParseError {
  let result : Array[AtomLink] = []
  for i, n in atom_children(node, "link") {
    let p = path + ".link[\{i}]"
    let href = reference(n, needed_attr(n, "href", p), p + ".href")
    let rel = raw_attr(n, "rel").unwrap_or("alternate")
    let parts = iri_parts(rel) catch {
      _ => raise InvalidRequiredField(p + ".rel", "invalid relation")
    }
    if rel.is_empty() ||
      (
        parts.scheme is None &&
        (rel.contains("/") || rel.contains("?") || rel.contains("#"))
      ) {
      raise InvalidRequiredField(
        p + ".rel",
        "relation must be a simple name or absolute IRI",
      )
    }
    let type_ = raw_attr(n, "type")
    if type_ is Some(value) {
      let _ = media_type(value, p + ".type")
    }
    let hreflang = raw_attr(n, "hreflang")
    if hreflang is Some(value) {
      validate_language(value, p + ".hreflang", false)
    }
    for previous in result {
      if is_alternate(rel) &&
        is_alternate(previous.rel) &&
        same_media_type(previous.media_type, type_, p + ".type") &&
        previous.hreflang.map(s => s.to_lower()) ==
        hreflang.map(s => s.to_lower()) {
        raise InvalidRequiredField(
          p, "duplicate alternate type/hreflang combination",
        )
      }
    }
    let length = match raw_attr(n, "length") {
      Some(value) => {
        if value.is_empty() || !value.to_array().all(ascii_digit) {
          raise InvalidRequiredField(
            p + ".length",
            "expected nonnegative decimal integer",
          )
        }
        Some(@string.parse_uint64(value)) catch {
          _ => None
        }
      }
      None => None
    }
    result.push({
      href,
      rel,
      media_type: type_,
      hreflang,
      title: raw_attr(n, "title"),
      length,
      length_raw: raw_attr(n, "length"),
      raw: markup(n),
    })
  }
  result
}

///|
fn strict_categories(
  node : Node,
  path : String,
) -> Array[AtomCategory] raise ParseError {
  let result = []
  for i, n in atom_children(node, "category") {
    let p = path + ".category[\{i}]"
    let scheme = match raw_attr(n, "scheme") {
      Some(s) => {
        let _ = absolute_iri(s, p + ".scheme")
        Some(reference(n, s, p + ".scheme"))
      }
      None => None
    }
    result.push({
      term: needed_attr(n, "term", p),
      scheme,
      label: raw_attr(n, "label"),
      raw: markup(n),
    })
  }
  result
}

///|
fn metadata(
  node : Node,
  path : String,
  required : Bool,
) -> AtomMetadata raise ParseError {
  let id = match one(node, "id", path) {
    Some(n) => Some(absolute_iri(scalar(n, path + ".id"), path + ".id"))
    None =>
      if required {
        raise InvalidRequiredField(path + ".id", "missing element")
      } else {
        None
      }
  }
  let title = optional_construct(node, "title", path)
  let updated = match one(node, "updated", path) {
    Some(n) => Some(date_value(n, path + ".updated"))
    None => None
  }
  if required && title is None {
    raise InvalidRequiredField(path + ".title", "missing element")
  }
  if required && updated is None {
    raise InvalidRequiredField(path + ".updated", "missing element")
  }
  let generator = match one(node, "generator", path) {
    Some(n) =>
      Some(AtomGenerator::{
        value: scalar(n, path + ".generator"),
        uri: match raw_attr(n, "uri") {
          Some(v) => Some(reference(n, v, path + ".generator.uri"))
          None => None
        },
        version: raw_attr(n, "version"),
      })
    None => None
  }
  let icon = match one(node, "icon", path) {
    Some(n) => Some(reference(n, scalar(n, path + ".icon"), path + ".icon"))
    None => None
  }
  let logo = match one(node, "logo", path) {
    Some(n) => Some(reference(n, scalar(n, path + ".logo"), path + ".logo"))
    None => None
  }
  {
    id,
    title,
    updated,
    authors: strict_people(node, "author", path),
    contributors: strict_people(node, "contributor", path),
    categories: strict_categories(node, path),
    links: strict_links(node, path),
    rights: optional_construct(node, "rights", path),
    subtitle: optional_construct(node, "subtitle", path),
    generator,
    icon,
    logo,
    raw: markup(node),
  }
}

///|
fn binary_media(essence : String) -> Bool {
  essence != "text" &&
  essence != "html" &&
  essence != "xhtml" &&
  !essence.has_prefix("text/") &&
  !essence.has_suffix("/xml") &&
  !essence.has_suffix("+xml")
}

///|
fn decode_base64(value : String, path : String) -> Array[Byte] raise ParseError {
  let a = value
    .to_array()
    .filter(c => c != ' ' && c != '\t' && c != '\r' && c != '\n')
  if a.length() % 4 != 0 {
    raise InvalidRequiredField(path, "invalid Base64 length")
  }
  let mut padding = 0
  for i, c in a {
    if c == '=' {
      padding += 1
      if i < a.length() - 2 || padding > 2 {
        raise InvalidRequiredField(path, "invalid Base64 padding")
      }
    } else if padding > 0 ||
      (!ascii_alpha(c) && !ascii_digit(c) && c != '+' && c != '/') {
      raise InvalidRequiredField(path, "invalid Base64 character")
    }
  }
  let result : Array[Byte] = []
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_array()
  let values = a.map(c => {
    let mut value = 0
    for i, symbol in alphabet {
      if c == symbol {
        value = i
        break
      }
    }
    value
  })
  for i = 0; i < a.length(); i = i + 4 {
    result.push((values[i] * 4 + values[i + 1] / 16).to_byte())
    if a[i + 2] != '=' {
      result.push((values[i + 1] % 16 * 16 + values[i + 2] / 4).to_byte())
    }
    if a[i + 3] != '=' {
      result.push((values[i + 2] % 4 * 64 + values[i + 3]).to_byte())
    }
  }
  result
}

///|
fn strict_content(node : Node, path : String) -> AtomContent raise ParseError {
  let src = match raw_attr(node, "src") {
    Some(v) => Some(reference(node, v, path + ".src"))
    None => None
  }
  let kind = raw_attr(node, "type").unwrap_or(
    if src is Some(_) {
      "application/octet-stream"
    } else {
      "text"
    },
  )
  let essence = if kind == "text" || kind == "html" || kind == "xhtml" {
    kind
  } else {
    media_type(kind, path + ".type")
  }
  if essence.has_prefix("multipart/") || essence.has_prefix("message/") {
    raise InvalidRequiredField(
      path + ".type",
      "composite content media types are not allowed",
    )
  }
  let value = if src is Some(_) {
    if !node.content.is_empty() {
      raise InvalidRequiredField(path, "content with src must be empty")
    }
    if kind == "text" || kind == "html" || kind == "xhtml" {
      raise InvalidRequiredField(
        path + ".type",
        "src requires a MIME media type",
      )
    }
    ""
  } else if essence == "xhtml" {
    descendant_text(xhtml_div(node, path))
  } else if essence == "text" ||
    essence == "html" ||
    essence.has_prefix("text/") {
    scalar(node, path)
  } else if binary_media(essence) {
    let v = scalar(node, path)
    v
  } else {
    descendant_text(node)
  }
  {
    media_type: if src is Some(_) {
      raw_attr(node, "type")
    } else {
      Some(kind)
    },
    value,
    decoded_bytes: if src is None && binary_media(essence) {
      Some(decode_base64(value, path))
    } else {
      None
    },
    src,
    markup: if src is None && essence == "xhtml" {
      markup(xhtml_div(node, path)).content
    } else {
      markup(node).content
    },
    raw: markup(node),
    language: node.language,
    base_uri: node.base_uri,
  }
}

///|
fn known_atom_name(name : String) -> Bool {
  match name {
    "feed"
    | "entry"
    | "id"
    | "title"
    | "updated"
    | "published"
    | "author"
    | "contributor"
    | "category"
    | "link"
    | "rights"
    | "subtitle"
    | "summary"
    | "content"
    | "source"
    | "generator"
    | "icon"
    | "logo"
    | "name"
    | "uri"
    | "email" => true
    _ => false
  }
}

///|
fn container_structure(
  node : Node,
  kind : String,
  path : String,
) -> Unit raise ParseError {
  if !node.text.to_string().trim(chars=" \t\r\n").is_empty() {
    raise InvalidRequiredField(
      path, "container must not contain non-whitespace text",
    )
  }
  let mut saw_entry = false
  for child in node.children {
    if child.name.namespace_uri != Some("http://www.w3.org/2005/Atom") {
      continue
    }
    let name = child.name.local_name
    if !known_atom_name(name) {
      continue
    } // forward-compatible Atom vocabulary
    let allowed = if kind == "person" {
      name == "name" || name == "uri" || name == "email"
    } else {
      match name {
        "id"
        | "title"
        | "updated"
        | "author"
        | "contributor"
        | "category"
        | "link"
        | "rights" => true
        "entry" => kind == "feed"
        "published" | "source" | "summary" | "content" => kind == "entry"
        "subtitle" | "generator" | "icon" | "logo" => kind != "entry"
        _ => false
      }
    }
    if !allowed {
      raise InvalidRequiredField(
        path + "." + name,
        "element is not allowed in this container",
      )
    }
    if kind == "feed" {
      if name == "entry" {
        saw_entry = true
      } else if saw_entry {
        raise InvalidRequiredField(
          path + "." + name,
          "feed metadata must precede entries",
        )
      }
    }
  }
}

///|
fn strict_entry(
  node : Node,
  path : String,
  inherited_authors : Array[AtomPerson],
  inherited_rights : AtomText?,
) -> AtomEntry raise ParseError {
  container_structure(node, "entry", path)
  let meta = metadata(node, path, true)
  let source = match one(node, "source", path) {
    Some(n) => {
      container_structure(n, "source", path + ".source")
      Some(metadata(n, path + ".source", false))
    }
    None => None
  }
  let authors = if !meta.authors.is_empty() {
    meta.authors
  } else if source is Some(s) && !s.authors.is_empty() {
    s.authors
  } else {
    inherited_authors
  }
  if authors.is_empty() {
    raise InvalidRequiredField(
      path + ".author",
      "author required on entry, source or containing feed",
    )
  }
  let published = match one(node, "published", path) {
    Some(n) => Some(date_value(n, path + ".published"))
    None => None
  }
  let summary = optional_construct(node, "summary", path)
  let content = match one(node, "content", path) {
    Some(n) => Some(strict_content(n, path + ".content"))
    None => None
  }
  if content is None && !meta.links.any(l => is_alternate(l.rel)) {
    raise InvalidRequiredField(
      path + ".link",
      "entry without content needs an alternate link",
    )
  }
  if content is Some(c) {
    let raw_kind = c.media_type.unwrap_or("text")
    let kind = if raw_kind == "text" ||
      raw_kind == "html" ||
      raw_kind == "xhtml" {
      raw_kind
    } else {
      media_type(raw_kind, path + ".content.type")
    }
    if (c.src is Some(_) || binary_media(kind)) && summary is None {
      raise InvalidRequiredField(
        path + ".summary",
        "summary required for external or Base64 content",
      )
    }
  }
  {
    metadata: meta,
    published,
    summary,
    content,
    source,
    effective_authors: authors,
    effective_rights: match meta.rights {
      Some(r) => Some(r)
      None => inherited_rights
    },
  }
}

///|
fn strict_document(
  input : String,
  base : String?,
) -> AtomDocument raise ParseError {
  if base is Some(b) {
    let _ = absolute_iri(b, "document_uri")
  }
  let root = document_tree(input, base, strict_declaration=true)
  validate_document_languages(root)
  if named(root, "entry") {
    return EntryDocument(strict_entry(root, "entry", [], None))
  }
  if !named(root, "feed") {
    raise InvalidAtomRoot(root.name.local_name)
  }
  container_structure(root, "feed", "feed")
  let meta = metadata(root, "feed", true)
  let entries = []
  for i, n in atom_children(root, "entry") {
    let entry = strict_entry(n, "feed.entry[\{i}]", meta.authors, meta.rights)
    if meta.authors.is_empty() && entry.metadata.authors.is_empty() {
      raise InvalidRequiredField(
        "feed.author", "feed author required unless every entry has its own author",
      )
    }
    entries.push(entry)
  }
  FeedDocument({ metadata: meta, entries, })
}

///|
/// Strict Atom document API. Feed and standalone Entry retain distinct types.
pub fn parse_document(input : String) -> AtomDocument raise ParseError {
  strict_document(input, None)
}

///|
/// Use the retrieval URI when XML Base does not supply an absolute base.
pub fn parse_document_with_base(
  input : String,
  document_uri : String,
) -> AtomDocument raise ParseError {
  strict_document(input, Some(document_uri))
}
