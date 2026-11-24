// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for Author with fn equal(self, other) {
  self.name == other.name &&
  self.url == other.url &&
  self.avatar == other.avatar
}

///|
pub impl @debug.Debug for Author with fn to_repr(self) {
  @debug.Repr::record({
    "name": @debug.Repr::Repr(self.name),
    "url": @debug.Repr::Repr(self.url),
    "avatar": @debug.Repr::Repr(self.avatar),
  })
}

///|
pub impl Eq for Attachment with fn equal(self, other) {
  self.url == other.url &&
  self.mime_type == other.mime_type &&
  self.title == other.title &&
  self.size_in_bytes == other.size_in_bytes &&
  self.duration_in_seconds == other.duration_in_seconds
}

///|
pub impl @debug.Debug for Attachment with fn to_repr(self) {
  @debug.Repr::record({
    "url": @debug.Repr::Repr(self.url),
    "mime_type": @debug.Repr::Repr(self.mime_type),
    "title": @debug.Repr::Repr(self.title),
    "size_in_bytes": @debug.Repr::Repr(self.size_in_bytes),
    "duration_in_seconds": @debug.Repr::Repr(self.duration_in_seconds),
  })
}

///|
pub impl Eq for FeedLink with fn equal(self, other) {
  self.url == other.url &&
  self.rel == other.rel &&
  self.media_type == other.media_type
}

///|
pub impl @debug.Debug for FeedLink with fn to_repr(self) {
  @debug.Repr::record({
    "url": @debug.Repr::Repr(self.url),
    "rel": @debug.Repr::Repr(self.rel),
    "media_type": @debug.Repr::Repr(self.media_type),
  })
}

///|
pub impl Eq for FeedItem with fn equal(self, other) {
  self.id == other.id &&
  self.title == other.title &&
  self.url == other.url &&
  self.external_url == other.external_url &&
  self.authors == other.authors &&
  self.summary == other.summary &&
  self.content_text == other.content_text &&
  self.content_html == other.content_html &&
  self.published == other.published &&
  self.published_at == other.published_at &&
  self.updated == other.updated &&
  self.updated_at == other.updated_at &&
  self.language == other.language &&
  self.categories == other.categories &&
  self.attachments == other.attachments
}

///|
pub impl @debug.Debug for FeedItem with fn to_repr(self) {
  @debug.Repr::record({
    "id": @debug.Repr::Repr(self.id),
    "title": @debug.Repr::Repr(self.title),
    "url": @debug.Repr::Repr(self.url),
    "external_url": @debug.Repr::Repr(self.external_url),
    "authors": @debug.Repr::Repr(self.authors),
    "summary": @debug.Repr::Repr(self.summary),
    "content_text": @debug.Repr::Repr(self.content_text),
    "content_html": @debug.Repr::Repr(self.content_html),
    "published": @debug.Repr::Repr(self.published),
    "published_at": @debug.Repr::Repr(self.published_at),
    "updated": @debug.Repr::Repr(self.updated),
    "updated_at": @debug.Repr::Repr(self.updated_at),
    "language": @debug.Repr::Repr(self.language),
    "categories": @debug.Repr::Repr(self.categories),
    "attachments": @debug.Repr::Repr(self.attachments),
  })
}

///|
pub impl Eq for Feed with fn equal(self, other) {
  self.title == other.title &&
  self.description == other.description &&
  self.home_page_url == other.home_page_url &&
  self.feed_url == other.feed_url &&
  self.language == other.language &&
  self.authors == other.authors &&
  self.categories == other.categories &&
  self.updated == other.updated &&
  self.updated_at == other.updated_at &&
  self.items == other.items
}

///|
pub impl @debug.Debug for Feed with fn to_repr(self) {
  @debug.Repr::record({
    "title": @debug.Repr::Repr(self.title),
    "description": @debug.Repr::Repr(self.description),
    "home_page_url": @debug.Repr::Repr(self.home_page_url),
    "feed_url": @debug.Repr::Repr(self.feed_url),
    "language": @debug.Repr::Repr(self.language),
    "authors": @debug.Repr::Repr(self.authors),
    "categories": @debug.Repr::Repr(self.categories),
    "updated": @debug.Repr::Repr(self.updated),
    "updated_at": @debug.Repr::Repr(self.updated_at),
    "items": @debug.Repr::Repr(self.items),
  })
}
