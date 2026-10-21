///|
pub using @atom {
  type AtomDocument,
  type AtomDate,
  type AtomFeed,
  type AtomEntry,
  type AtomMetadata,
  type AtomPerson,
  type AtomLink,
  type AtomCategory,
  type AtomGenerator,
  type AtomText,
  type AtomContent,
  type IriReference,
  type Markup,
  type MarkupAttribute,
  type MarkupContent,
}

///|
/// Parse and normalize an Atom 1.0 feed into the unified model.
pub fn parse_atom(input : String) -> @model.Feed raise @atom.ParseError {
  @atom.parse(input)
}

///|
/// Parse and validate an Atom Feed or Entry Document, retaining Atom metadata.
pub fn parse_atom_document(
  input : String,
) -> @atom.AtomDocument raise @atom.ParseError {
  @atom.parse_document(input)
}

///|
pub fn parse_atom_document_with_base(
  input : String,
  document_uri : String,
) -> @atom.AtomDocument raise @atom.ParseError {
  @atom.parse_document_with_base(input, document_uri)
}
