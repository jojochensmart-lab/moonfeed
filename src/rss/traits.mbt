// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for ParseError with fn equal(self, other) {
  match (self, other) {
    (InvalidXml(a0), InvalidXml(b0)) => a0 == b0
    (UnsupportedRssVersion(a0), UnsupportedRssVersion(b0)) => a0 == b0
    (MissingChannel, MissingChannel) => true
    (MissingChannelTitle, MissingChannelTitle) => true
    (MissingChannelLink, MissingChannelLink) => true
    (MissingChannelDescription, MissingChannelDescription) => true
    (InvalidEnclosure(a0, a1), InvalidEnclosure(b0, b1)) => a0 == b0 && a1 == b1
    (InvalidRequiredField(a0, a1), InvalidRequiredField(b0, b1)) =>
      a0 == b0 && a1 == b1
    _ => false
  }
}

///|
pub impl @debug.Debug for ParseError with fn to_repr(self) {
  match self {
    InvalidXml(v0) =>
      @debug.Repr::ctor("InvalidXml", [(None, @debug.Repr::Repr(v0))])
    UnsupportedRssVersion(v0) =>
      @debug.Repr::ctor("UnsupportedRssVersion", [(None, @debug.Repr::Repr(v0))])
    MissingChannel => @debug.Repr::ctor("MissingChannel", [])
    MissingChannelTitle => @debug.Repr::ctor("MissingChannelTitle", [])
    MissingChannelLink => @debug.Repr::ctor("MissingChannelLink", [])
    MissingChannelDescription =>
      @debug.Repr::ctor("MissingChannelDescription", [])
    InvalidEnclosure(v0, v1) =>
      @debug.Repr::ctor("InvalidEnclosure", [
        (None, @debug.Repr::Repr(v0)),
        (None, @debug.Repr::Repr(v1)),
      ])
    InvalidRequiredField(v0, v1) =>
      @debug.Repr::ctor("InvalidRequiredField", [
        (None, @debug.Repr::Repr(v0)),
        (None, @debug.Repr::Repr(v1)),
      ])
  }
}
