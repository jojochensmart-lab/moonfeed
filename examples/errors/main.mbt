///|
fn main {
  let rejected = try {
    ignore(
      @moonfeed.parse(
        "{\"version\":\"https://jsonfeed.org/version/1.1\",\"items\":[]}",
      ),
    )
    false
  } catch {
    @moonfeed.JsonFeed(error) => {
      println(@debug.to_string(error))
      true
    }
    _ => false
  }
  if !rejected {
    abort("expected a typed JSON Feed error")
  }
  let unknown = try {
    ignore(@moonfeed.parse("<html/>"))
    false
  } catch {
    @moonfeed.Detect(_) => true
    _ => false
  }
  if !unknown {
    abort("expected a typed detection error")
  }
  println("Errors: PASS (missing title and unsupported format rejected)")
}
