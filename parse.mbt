///|
/// Errors retain either a detection failure or the typed error from the selected parser.
pub(all) suberror ParseError {
  Detect(@detect.DetectError)
  JsonFeed(@jsonfeed.ParseError)
  Rss(@rss.ParseError)
  Atom(@atom.ParseError)
} derive(Eq, @debug.Debug)

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
  let normalized = strip_utf8_bom(input)
  let format = @detect.detect_format(normalized) catch {
    error => raise Detect(error)
  }
  match format {
    JsonFeed =>
      @jsonfeed.parse(normalized) catch {
        error => raise JsonFeed(error)
      }
    Rss => @rss.parse(normalized) catch { error => raise Rss(error) }
    Atom => @atom.parse(normalized) catch { error => raise Atom(error) }
  }
}

///|
fn strip_utf8_bom(input : String) -> String {
  let chars = input.to_array()
  if !chars.is_empty() && chars[0].to_int() == 0xFEFF {
    let out = StringBuilder()
    for index = 1; index < chars.length(); index = index + 1 {
      out.write_char(chars[index])
    }
    out.to_string()
  } else {
    input
  }
}
