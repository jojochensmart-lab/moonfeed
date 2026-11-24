// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for ParseError with fn equal(self, other) {
  match (self, other) {
    (InvalidJson(a0), InvalidJson(b0)) => a0 == b0
    (MissingField(a0), MissingField(b0)) => a0 == b0
    (InvalidType(a0, a1), InvalidType(b0, b1)) => a0 == b0 && a1 == b1
    (UnsupportedVersion(a0), UnsupportedVersion(b0)) => a0 == b0
    (InvalidValue(a0, a1), InvalidValue(b0, b1)) => a0 == b0 && a1 == b1
    _ => false
  }
}

///|
pub impl @debug.Debug for ParseError with fn to_repr(self) {
  match self {
    InvalidJson(v0) =>
      @debug.Repr::ctor("InvalidJson", [(None, @debug.Repr::Repr(v0))])
    MissingField(v0) =>
      @debug.Repr::ctor("MissingField", [(None, @debug.Repr::Repr(v0))])
    InvalidType(v0, v1) =>
      @debug.Repr::ctor("InvalidType", [
        (None, @debug.Repr::Repr(v0)),
        (None, @debug.Repr::Repr(v1)),
      ])
    UnsupportedVersion(v0) =>
      @debug.Repr::ctor("UnsupportedVersion", [(None, @debug.Repr::Repr(v0))])
    InvalidValue(v0, v1) =>
      @debug.Repr::ctor("InvalidValue", [
        (None, @debug.Repr::Repr(v0)),
        (None, @debug.Repr::Repr(v1)),
      ])
  }
}
