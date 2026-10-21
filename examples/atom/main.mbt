///|
fn main {
  let default_namespace =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.org/news/"><id>urn:entry:demo</id><title>MoonFeed</title><updated>2026-10-20T12:00:00Z</updated><author><name>MoonBit</name></author><link href="../article"/><content>Hello</content></entry>
  let explicit_prefix =
    #|<x:entry xmlns:x="http://www.w3.org/2005/Atom" xml:base="https://example.org/news/"><x:id>urn:entry:demo</x:id><x:title>MoonFeed</x:title><x:updated>2026-10-20T12:00:00Z</x:updated><x:author><x:name>MoonBit</x:name></x:author><x:link href="../article"/><x:content>Hello</x:content></x:entry>
  try {
    match
      (
        @moonfeed.parse_atom_document(default_namespace),
        @moonfeed.parse_atom_document(explicit_prefix),
      ) {
      (
        @moonfeed.AtomDocument::EntryDocument(a),
        @moonfeed.AtomDocument::EntryDocument(b),
      ) => {
        assert_eq(a.metadata.id, b.metadata.id)
        assert_eq(
          a.metadata.title.unwrap().value,
          b.metadata.title.unwrap().value,
        )
        assert_eq(
          a.metadata.updated.unwrap().raw,
          b.metadata.updated.unwrap().raw,
        )
        assert_eq(
          a.metadata.updated.unwrap().unix_seconds,
          b.metadata.updated.unwrap().unix_seconds,
        )
        assert_eq(a.effective_authors[0].name, b.effective_authors[0].name)
        assert_eq(
          a.metadata.links[0].href.resolved,
          b.metadata.links[0].href.resolved,
        )
        assert_eq(a.content.unwrap().value, b.content.unwrap().value)
        println("Equivalent Entry Documents: PASS")
        println(a.metadata.id.unwrap())
        println(a.metadata.links[0].href.raw)
        println(a.metadata.links[0].href.resolved)
      }
      _ => abort("expected two Entry Documents")
    }
  } catch {
    _ => abort("Atom document validation failed")
  }
}
