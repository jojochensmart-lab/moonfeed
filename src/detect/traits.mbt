// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for FeedFormat with fn equal(self, other) {
  match (self, other) {
    (JsonFeed, JsonFeed) => true
    (Rss, Rss) => true
    (Atom, Atom) => true
    _ => false
  }
}

///|
pub impl @debug.Debug for FeedFormat with fn to_repr(self) {
  match self {
    JsonFeed => @debug.Repr::ctor("JsonFeed", [])
    Rss => @debug.Repr::ctor("Rss", [])
    Atom => @debug.Repr::ctor("Atom", [])
  }
}

///|
pub impl Eq for DetectError with fn equal(self, other) {
  match (self, other) {
    (EmptyInput, EmptyInput) => true
    (UnknownFormat, UnknownFormat) => true
    (MalformedPrefix(a0), MalformedPrefix(b0)) => a0 == b0
    _ => false
  }
}

///|
pub impl @debug.Debug for DetectError with fn to_repr(self) {
  match self {
    EmptyInput => @debug.Repr::ctor("EmptyInput", [])
    UnknownFormat => @debug.Repr::ctor("UnknownFormat", [])
    MalformedPrefix(v0) =>
      @debug.Repr::ctor("MalformedPrefix", [(None, @debug.Repr::Repr(v0))])
  }
}
