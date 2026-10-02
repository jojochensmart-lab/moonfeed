///|
/// Retains the source date while exposing its UTC Unix timestamp at whole-second precision.
/// Fractional seconds are validated and truncated toward the beginning of the represented second.
pub(all) struct DateTime {
  raw : String
  unix_seconds : Int64
} derive(Eq, @debug.Debug)

///|
pub fn DateTime::equal(self : DateTime, other : DateTime) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn DateTime::not_equal(self : DateTime, other : DateTime) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn DateTime::to_repr(self : DateTime) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}

///|
/// Compare normalized UTC instants, ignoring source spelling and timezone offset.
pub fn DateTime::compare(self : DateTime, other : DateTime) -> Int {
  if self.unix_seconds < other.unix_seconds {
    -1
  } else if self.unix_seconds > other.unix_seconds {
    1
  } else {
    0
  }
}

///|
/// Date parsing failures are typed so callers can distinguish malformed and unsupported input.
pub(all) suberror DateTimeError {
  InvalidFormat
  InvalidYear
  InvalidMonth
  InvalidDay
  InvalidTime
  InvalidOffset
  UnsupportedTimezone(String)
} derive(Eq, @debug.Debug)

///|
pub fn DateTimeError::equal(
  self : DateTimeError,
  other : DateTimeError,
) -> Bool {
  Eq::equal(self, other)
}

///|
pub fn DateTimeError::not_equal(
  self : DateTimeError,
  other : DateTimeError,
) -> Bool {
  !Eq::equal(self, other)
}

///|
pub fn DateTimeError::to_repr(self : DateTimeError) -> @debug.Repr {
  @debug.Debug::to_repr(self)
}
