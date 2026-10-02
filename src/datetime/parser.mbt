///|
fn digit(ch : Char) -> Int? {
  match ch {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    _ => None
  }
}

///|
fn number(chars : Array[Char], start : Int, end : Int) -> Int? {
  if start >= end || start < 0 || end > chars.length() {
    return None
  }
  let mut value = 0
  for index = start; index < end; index = index + 1 {
    match digit(chars[index]) {
      Some(d) => value = value * 10 + d
      None => return None
    }
  }
  Some(value)
}

///|
fn parse_number(value : String) -> Int? {
  let chars = value.to_array()
  number(chars, 0, chars.length())
}

///|
fn leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn month_length(year : Int, month : Int) -> Int {
  match month {
    2 => if leap_year(year) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn validate_date(
  year : Int,
  month : Int,
  day : Int,
) -> Unit raise DateTimeError {
  if year < 1 || year > 9999 {
    raise InvalidYear
  }
  if month < 1 || month > 12 {
    raise InvalidMonth
  }
  if day < 1 || day > month_length(year, month) {
    raise InvalidDay
  }
}

///|
fn validate_clock(
  hour : Int,
  minute : Int,
  second : Int,
) -> Unit raise DateTimeError {
  if hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59 {
    raise InvalidTime
  }
}

///|
/// Return Gregorian calendar days relative to 1970-01-01, then apply the numeric offset.
fn to_unix_seconds(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  offset_seconds : Int,
) -> Int64 {
  let y = if month <= 2 { year - 1 } else { year }
  let era = y / 400
  let year_of_era = y - era * 400
  let month_prime = if month > 2 { month - 3 } else { month + 9 }
  let day_of_year = (153 * month_prime + 2) / 5 + day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  let days = era * 146097 + day_of_era - 719468
  Int64::from_int(days) * 86400L +
  Int64::from_int(hour * 3600 + minute * 60 + second - offset_seconds)
}

///|
fn signed_offset(
  chars : Array[Char],
  start : Int,
  colonized : Bool,
) -> Int raise DateTimeError {
  let expected = if colonized { 6 } else { 5 }
  if start + expected != chars.length() ||
    (chars[start] != '+' && chars[start] != '-') {
    raise InvalidOffset
  }
  let hour = match number(chars, start + 1, start + 3) {
    Some(value) => value
    None => raise InvalidOffset
  }
  let minute_start = if colonized {
    if chars[start + 3] != ':' {
      raise InvalidOffset
    }
    start + 4
  } else {
    start + 3
  }
  let minute = match number(chars, minute_start, minute_start + 2) {
    Some(value) => value
    None => raise InvalidOffset
  }
  if hour > 23 || minute > 59 {
    raise InvalidOffset
  }
  let magnitude = hour * 3600 + minute * 60
  if chars[start] == '+' {
    magnitude
  } else {
    -magnitude
  }
}

///|
fn rfc3339_offset(chars : Array[Char], start : Int) -> Int raise DateTimeError {
  if start >= chars.length() {
    raise InvalidFormat
  }
  match chars[start] {
    'Z' | 'z' =>
      if start + 1 == chars.length() {
        0
      } else {
        raise InvalidFormat
      }
    '+' | '-' => signed_offset(chars, start, true)
    _ => raise InvalidFormat
  }
}

///|
/// Parse strict RFC 3339 timestamps with optional fractional seconds and explicit UTC offset.
pub fn parse_rfc3339(input : String) -> DateTime raise DateTimeError {
  let chars = input.to_array()
  if chars.length() < 20 ||
    chars[4] != '-' ||
    chars[7] != '-' ||
    (chars[10] != 'T' && chars[10] != 't') ||
    chars[13] != ':' ||
    chars[16] != ':' {
    raise InvalidFormat
  }
  let year = match number(chars, 0, 4) {
    Some(value) => value
    None => raise InvalidYear
  }
  let month = match number(chars, 5, 7) {
    Some(value) => value
    None => raise InvalidMonth
  }
  let day = match number(chars, 8, 10) {
    Some(value) => value
    None => raise InvalidDay
  }
  validate_date(year, month, day)
  let hour = match number(chars, 11, 13) {
    Some(value) => value
    None => raise InvalidTime
  }
  let minute = match number(chars, 14, 16) {
    Some(value) => value
    None => raise InvalidTime
  }
  let second = match number(chars, 17, 19) {
    Some(value) => value
    None => raise InvalidTime
  }
  validate_clock(hour, minute, second)
  let mut zone_start = 19
  if zone_start < chars.length() && chars[zone_start] == '.' {
    zone_start += 1
    let fraction_start = zone_start
    while zone_start < chars.length() && digit(chars[zone_start]) is Some(_) {
      zone_start += 1
    }
    if zone_start == fraction_start {
      raise InvalidTime
    }
  }
  let offset = rfc3339_offset(chars, zone_start)
  {
    raw: input,
    unix_seconds: to_unix_seconds(
      year, month, day, hour, minute, second, offset,
    ),
  }
}

///|
fn rss_month(value : String) -> Int? {
  match value {
    "Jan" | "jan" => Some(1)
    "Feb" | "feb" => Some(2)
    "Mar" | "mar" => Some(3)
    "Apr" | "apr" => Some(4)
    "May" | "may" => Some(5)
    "Jun" | "jun" => Some(6)
    "Jul" | "jul" => Some(7)
    "Aug" | "aug" => Some(8)
    "Sep" | "sep" => Some(9)
    "Oct" | "oct" => Some(10)
    "Nov" | "nov" => Some(11)
    "Dec" | "dec" => Some(12)
    _ => None
  }
}

///|
fn weekday_token(value : String) -> Bool {
  match value {
    "Mon," | "Tue," | "Wed," | "Thu," | "Fri," | "Sat," | "Sun," => true
    _ => false
  }
}

///|
fn whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn tokens(input : String) -> Array[String] {
  let result = []
  let mut part = StringBuilder()
  let mut active = false
  for ch in input.to_array() {
    if whitespace(ch) {
      if active {
        result.push(part.to_string())
        part = StringBuilder()
        active = false
      }
    } else {
      part.write_char(ch)
      active = true
    }
  }
  if active {
    result.push(part.to_string())
  }
  result
}

///|
fn rss_offset(value : String) -> Int raise DateTimeError {
  match value {
    "GMT" | "UTC" | "gmt" | "utc" => 0
    _ => {
      let chars = value.to_array()
      if chars.is_empty() {
        raise InvalidOffset
      }
      if chars[0] == '+' || chars[0] == '-' {
        signed_offset(chars, 0, chars.length() == 6)
      } else {
        raise UnsupportedTimezone(value)
      }
    }
  }
}

///|
/// Parse common RSS/RFC 822 and RFC 1123 dates. Unknown timezone abbreviations are rejected.
pub fn parse_rss_datetime(input : String) -> DateTime raise DateTimeError {
  let parts = tokens(input.trim(chars=" \t\r\n").to_owned())
  let start = if !parts.is_empty() && weekday_token(parts[0]) { 1 } else { 0 }
  if parts.length() - start != 5 {
    raise InvalidFormat
  }
  let day = match parse_number(parts[start]) {
    Some(value) => value
    None => raise InvalidDay
  }
  let month = match rss_month(parts[start + 1]) {
    Some(value) => value
    None => raise InvalidMonth
  }
  let year = match parse_number(parts[start + 2]) {
    Some(value) => value
    None => raise InvalidYear
  }
  validate_date(year, month, day)
  let time = parts[start + 3].to_array()
  let colons = []
  for index, ch in time {
    if ch == ':' {
      colons.push(index)
    }
  }
  if colons.length() != 1 && colons.length() != 2 {
    raise InvalidTime
  }
  let hour = match number(time, 0, colons[0]) {
    Some(value) => value
    None => raise InvalidTime
  }
  let minute_end = if colons.length() == 2 { colons[1] } else { time.length() }
  let minute = match number(time, colons[0] + 1, minute_end) {
    Some(value) => value
    None => raise InvalidTime
  }
  let second = if colons.length() == 2 {
    match number(time, colons[1] + 1, time.length()) {
      Some(value) => value
      None => raise InvalidTime
    }
  } else {
    0
  }
  validate_clock(hour, minute, second)
  let offset = rss_offset(parts[start + 4])
  {
    raw: input,
    unix_seconds: to_unix_seconds(
      year, month, day, hour, minute, second, offset,
    ),
  }
}

///|
/// Parse RFC 3339 first, then common RSS/RFC 822 date spellings.
pub fn parse_datetime(input : String) -> DateTime raise DateTimeError {
  let chars = input.to_array()
  if chars.length() > 10 &&
    chars[4] == '-' &&
    (chars[10] == 'T' || chars[10] == 't') {
    parse_rfc3339(input)
  } else {
    parse_rss_datetime(input)
  }
}

///|
/// Parse an optional source date without rejecting the containing feed when it is malformed.
pub fn parse_optional_datetime(input : String?) -> DateTime? {
  match input {
    Some(value) => Some(parse_datetime(value)) catch { _ => None }
    None => None
  }
}
