///|
pub fn parse_datetime(
  input : String,
) -> @datetime.DateTime raise @datetime.DateTimeError {
  @datetime.parse_datetime(input)
}

///|
pub fn parse_rfc3339(
  input : String,
) -> @datetime.DateTime raise @datetime.DateTimeError {
  @datetime.parse_rfc3339(input)
}

///|
pub fn parse_rss_datetime(
  input : String,
) -> @datetime.DateTime raise @datetime.DateTimeError {
  @datetime.parse_rss_datetime(input)
}
