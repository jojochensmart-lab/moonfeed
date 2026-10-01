///|
/// Parse and normalize an Atom 1.0 feed into the unified model.
pub fn parse_atom(input : String) -> @model.Feed raise @atom.ParseError {
  @atom.parse(input)
}
