///|
// Preserve the existing method API on both the July and current stable compilers.
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
