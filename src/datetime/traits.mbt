// Explicit trait implementations preserve the same API on MoonBit v0.10.14–v0.10.22.

///|
pub impl Eq for DateTime with fn equal(self, other) {
  self.raw == other.raw && self.unix_seconds == other.unix_seconds
}

///|
pub impl @debug.Debug for DateTime with fn to_repr(self) {
  @debug.Repr::record({
    "raw": @debug.Repr::Repr(self.raw),
    "unix_seconds": @debug.Repr::Repr(self.unix_seconds),
  })
}

///|
pub impl Eq for DateTimeError with fn equal(self, other) {
  match (self, other) {
    (InvalidFormat, InvalidFormat) => true
    (InvalidYear, InvalidYear) => true
    (InvalidMonth, InvalidMonth) => true
    (InvalidDay, InvalidDay) => true
    (InvalidTime, InvalidTime) => true
    (InvalidOffset, InvalidOffset) => true
    (UnsupportedTimezone(a0), UnsupportedTimezone(b0)) => a0 == b0
    _ => false
  }
}

///|
pub impl @debug.Debug for DateTimeError with fn to_repr(self) {
  match self {
    InvalidFormat => @debug.Repr::ctor("InvalidFormat", [])
    InvalidYear => @debug.Repr::ctor("InvalidYear", [])
    InvalidMonth => @debug.Repr::ctor("InvalidMonth", [])
    InvalidDay => @debug.Repr::ctor("InvalidDay", [])
    InvalidTime => @debug.Repr::ctor("InvalidTime", [])
    InvalidOffset => @debug.Repr::ctor("InvalidOffset", [])
    UnsupportedTimezone(v0) =>
      @debug.Repr::ctor("UnsupportedTimezone", [(None, @debug.Repr::Repr(v0))])
  }
}
