///|
// Explicit forwarding preserves the pre-0.10.4 method API without new extend syntax.

///|
pub fn Author::equal(self : Author, other : Author) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn Author::not_equal(self : Author, other : Author) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn Author::to_repr(self : Author) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
pub fn Attachment::equal(self : Attachment, other : Attachment) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn Attachment::not_equal(self : Attachment, other : Attachment) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn Attachment::to_repr(self : Attachment) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
pub fn FeedLink::equal(self : FeedLink, other : FeedLink) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn FeedLink::not_equal(self : FeedLink, other : FeedLink) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn FeedLink::to_repr(self : FeedLink) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
pub fn FeedItem::equal(self : FeedItem, other : FeedItem) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn FeedItem::not_equal(self : FeedItem, other : FeedItem) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn FeedItem::to_repr(self : FeedItem) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
pub fn Feed::equal(self : Feed, other : Feed) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn Feed::not_equal(self : Feed, other : Feed) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn Feed::to_repr(self : Feed) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}
