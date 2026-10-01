///|
fn main {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"MoonFeed","items":[{"id":"hello","content_text":"Hello MoonBit!"}]}
  try {
    let feed = @moonfeed.parse_json_feed(input)
    println(feed.title)
    for item in feed.items {
      println(item.id)
      if item.content_text is Some(text) {
        println(text)
      }
    }
  } catch {
    @jsonfeed.InvalidJson(message) => println("Invalid JSON: " + message)
    @jsonfeed.MissingField(path) => println("Missing field: " + path)
    @jsonfeed.InvalidType(path, expected) =>
      println(path + " must be " + expected)
    @jsonfeed.UnsupportedVersion(version) =>
      println("Unsupported version: " + version)
    @jsonfeed.InvalidValue(path, message) => println(path + ": " + message)
  }
}
