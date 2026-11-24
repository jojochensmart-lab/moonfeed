// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for ParseError with fn equal(self, other) {
  match (self, other) {
    (Detect(a0), Detect(b0)) => a0 == b0
    (JsonFeed(a0), JsonFeed(b0)) => a0 == b0
    (Rss(a0), Rss(b0)) => a0 == b0
    (Atom(a0), Atom(b0)) => a0 == b0
    _ => false
  }
}

///|
pub impl @debug.Debug for ParseError with fn to_repr(self) {
  match self {
    Detect(v0) => @debug.Repr::ctor("Detect", [(None, @debug.Repr::Repr(v0))])
    JsonFeed(v0) =>
      @debug.Repr::ctor("JsonFeed", [(None, @debug.Repr::Repr(v0))])
    Rss(v0) => @debug.Repr::ctor("Rss", [(None, @debug.Repr::Repr(v0))])
    Atom(v0) => @debug.Repr::ctor("Atom", [(None, @debug.Repr::Repr(v0))])
  }
}
