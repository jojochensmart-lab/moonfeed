///|
/// Parse supported JSON Feed 1.1 fields into the unified Feed model.
pub fn parse_json_feed(
  input : String,
) -> @model.Feed raise @jsonfeed.ParseError {
  @jsonfeed.parse(input)
}
