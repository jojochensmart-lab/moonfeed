///|
fn main {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"MoonFeed","items":[{"id":"hello","content_text":"Hello MoonBit!"}]}
  try {
    let feed = @moonfeed.parse(input)
    println(feed.title)
    for item in feed.items {
      println(item.id)
      if item.content_text is Some(text) {
        println(text)
      }
    }
  } catch {
    @moonfeed.Detect(_) => println("Format detection failed")
    @moonfeed.JsonFeed(_) => println("Invalid JSON Feed")
    @moonfeed.Rss(_) => println("Invalid RSS feed")
    @moonfeed.Atom(_) => println("Invalid Atom feed")
  }
}
