// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for ParseError with fn equal(self, other) {
  match (self, other) {
    (InvalidXml(a0), InvalidXml(b0)) => a0 == b0
    (InvalidAtomRoot(a0), InvalidAtomRoot(b0)) => a0 == b0
    (InvalidRequiredField(a0, a1), InvalidRequiredField(b0, b1)) =>
      a0 == b0 && a1 == b1
    (InvalidDateTime(a0, a1), InvalidDateTime(b0, b1)) => a0 == b0 && a1 == b1
    _ => false
  }
}

///|
pub impl @debug.Debug for ParseError with fn to_repr(self) {
  match self {
    InvalidXml(v0) =>
      @debug.Repr::ctor("InvalidXml", [(None, @debug.Repr::Repr(v0))])
    InvalidAtomRoot(v0) =>
      @debug.Repr::ctor("InvalidAtomRoot", [(None, @debug.Repr::Repr(v0))])
    InvalidRequiredField(v0, v1) =>
      @debug.Repr::ctor("InvalidRequiredField", [
        (None, @debug.Repr::Repr(v0)),
        (None, @debug.Repr::Repr(v1)),
      ])
    InvalidDateTime(v0, v1) =>
      @debug.Repr::ctor("InvalidDateTime", [
        (None, @debug.Repr::Repr(v0)),
        (None, @debug.Repr::Repr(v1)),
      ])
  }
}
