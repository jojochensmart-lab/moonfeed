///|
fn main {
  let input =
    #|<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:e="urn:extension" xml:base="https://example.org/" xml:lang="en"><a:id>urn:news</a:id><a:title>Releases</a:title><a:updated>2026-10-01T12:00:00Z</a:updated><a:author><a:name>Editor</a:name></a:author><e:title>Not the title</e:title><a:entry><a:id>urn:release:1</a:id><a:title>Version 1</a:title><a:updated>2026-10-01T12:00:00Z</a:updated><a:link href="releases/1"/><a:content>Released</a:content></a:entry></a:feed>
  try {
    let unified = @moonfeed.parse(input)
    assert_eq(unified.title, "Releases")
    assert_eq(unified.items[0].url, Some("https://example.org/releases/1"))
    match @moonfeed.parse_atom_document(input) {
      @moonfeed.AtomDocument::FeedDocument(feed) => {
        assert_eq(feed.entries.length(), 1)
        assert_eq(feed.entries[0].effective_authors[0].name, "Editor")
        assert_eq(feed.entries[0].metadata.links[0].href.raw, "releases/1")
      }
      _ => abort("expected Feed Document")
    }
    println(
      "Atom Feed: PASS (prefix, extensions, XML Base, author inheritance)",
    )
  } catch {
    _ => abort("Atom Feed example failed")
  }
}
