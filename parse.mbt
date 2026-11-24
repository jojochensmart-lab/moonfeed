///|
/// Errors retain either a detection failure or the typed error from the selected parser.
pub(all) suberror ParseError {
  Detect(@detect.DetectError)
  JsonFeed(@jsonfeed.ParseError)
  Rss(@rss.ParseError)
  Atom(@atom.ParseError)
}

///|
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

///|
/// Parse a JSON Feed 1.1, RSS 2.0, or Atom 1.0 document by its content.
pub fn parse(input : String) -> @model.Feed raise ParseError {
  let format = @detect.detect_format(input) catch {
    error => raise Detect(error)
  }
  match format {
    JsonFeed => @jsonfeed.parse(input) catch { error => raise JsonFeed(error) }
    Rss => @rss.parse(input) catch { error => raise Rss(error) }
    Atom => @atom.parse(input) catch { error => raise Atom(error) }
  }
}
