///|
fn strict_entry_xml(extra : String) -> String {
  "<entry xmlns='http://www.w3.org/2005/Atom'><id>urn:entry:1</id><title>Entry</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author>" +
  extra +
  "</entry>"
}

///|
fn strict_feed_xml(extra : String) -> String {
  "<feed xmlns='http://www.w3.org/2005/Atom'><id>urn:feed:1</id><title>Feed</title><updated>2003-12-13T18:30:02Z</updated><author><name>Editor</name></author>" +
  extra +
  "</feed>"
}

///|
fn strict_error(input : String) -> @atom.ParseError raise {
  @test.expect_error(() => @moonfeed.parse_atom_document(input))
}

///|
fn entry_document(input : String) -> @atom.AtomEntry raise {
  match @moonfeed.parse_atom_document(input) {
    @atom.EntryDocument(e) => e
    _ => fail("expected Entry Document")
  }
}

///|
fn feed_document(input : String) -> @atom.AtomFeed raise {
  match @moonfeed.parse_atom_document(input) {
    @atom.FeedDocument(f) => f
    _ => fail("expected Feed Document")
  }
}

///|
test "strict Atom standalone Entry Document retains metadata and content" {
  let e = entry_document(
    strict_entry_xml(
      "<link href='https://example.org/item'/><summary>Short</summary><content type='html'>&lt;p&gt;Body&lt;/p&gt;</content>",
    ),
  )
  assert_eq(e.metadata.id, Some("urn:entry:1"))
  assert_eq(e.metadata.title.unwrap().value, "Entry")
  assert_eq(e.metadata.updated.unwrap().unix_seconds, 1071340202L)
  assert_eq(e.effective_authors[0].name, "A")
  assert_eq(e.metadata.links[0].href.resolved, "https://example.org/item")
  assert_eq(e.summary.unwrap().value, "Short")
  assert_eq(e.content.unwrap().value, "<p>Body</p>")
  assert_eq(e.content.unwrap().media_type, Some("html"))
}

///|
test "strict Atom Entry arbitrary prefix is equivalent and foreign roots fail" {
  let e = entry_document(
    (
      #|<a:entry xmlns:a="http://www.w3.org/2005/Atom"><a:id>urn:entry:1</a:id><a:title>Entry</a:title><a:updated>2003-12-13T18:30:02Z</a:updated><a:author><a:name>A</a:name></a:author><a:content>Body</a:content></a:entry>
    ),
  )
  let d = entry_document(strict_entry_xml("<content>Body</content>"))
  assert_eq(e.metadata.id, d.metadata.id)
  assert_eq(e.metadata.title.unwrap().value, d.metadata.title.unwrap().value)
  assert_eq(e.effective_authors[0].name, d.effective_authors[0].name)
  assert_eq(e.content.unwrap().value, d.content.unwrap().value)
  assert_true(
    strict_error("<entry xmlns='urn:foreign'/>")
    is @atom.InvalidAtomRoot("entry"),
  )
  assert_true(strict_error("<x:entry/>") is @atom.InvalidXml(_))
}

///|
test "strict Atom Feed and Entry Documents keep distinct root variants" {
  assert_true(
    @moonfeed.parse_atom_document(strict_feed_xml("")) is @atom.FeedDocument(_),
  )
  assert_true(
    @moonfeed.parse_atom_document(strict_entry_xml("<content/>"))
    is @atom.EntryDocument(_),
  )
  assert_true(
    strict_error(strict_feed_xml("<source/>"))
    is @atom.InvalidRequiredField("feed.source", _),
  )
  assert_true(
    strict_error(strict_entry_xml("<subtitle>wrong</subtitle><content/>"))
    is @atom.InvalidRequiredField("entry.subtitle", _),
  )
}

///|
test "RFC3986 normal reference resolution examples" {
  let cases = [
    ("g:h", "g:h"),
    ("g", "http://a/b/c/g"),
    ("./g", "http://a/b/c/g"),
    ("g/", "http://a/b/c/g/"),
    ("/g", "http://a/g"),
    ("//g", "http://g"),
    ("?y", "http://a/b/c/d;p?y"),
    ("g?y", "http://a/b/c/g?y"),
    ("#s", "http://a/b/c/d;p?q#s"),
    ("g#s", "http://a/b/c/g#s"),
    ("g?y#s", "http://a/b/c/g?y#s"),
    (";x", "http://a/b/c/;x"),
    ("g;x", "http://a/b/c/g;x"),
    ("g;x?y#s", "http://a/b/c/g;x?y#s"),
    ("", "http://a/b/c/d;p?q"),
    (".", "http://a/b/c/"),
    ("./", "http://a/b/c/"),
    ("..", "http://a/b/"),
    ("../", "http://a/b/"),
    ("../g", "http://a/b/g"),
    ("../..", "http://a/"),
    ("../../", "http://a/"),
    ("../../g", "http://a/g"),
  ]
  for (reference, expected) in cases {
    let iri = @atom.resolve_reference(Some("http://a/b/c/d;p?q"), reference)
    assert_eq(iri.raw, reference)
    assert_eq(iri.resolved, expected)
    assert_true(iri.is_absolute)
  }
}

///|
test "RFC3986 abnormal reference resolution preserves query and fragment semantics" {
  let cases = [
    ("../../../g", "http://a/g"),
    ("../../../../g", "http://a/g"),
    ("/./g", "http://a/g"),
    ("/../g", "http://a/g"),
    ("g.", "http://a/b/c/g."),
    (".g", "http://a/b/c/.g"),
    ("g..", "http://a/b/c/g.."),
    ("..g", "http://a/b/c/..g"),
    ("./../g", "http://a/b/g"),
    ("./g/.", "http://a/b/c/g/"),
    ("g/./h", "http://a/b/c/g/h"),
    ("g/../h", "http://a/b/c/h"),
    ("g;x=1/./y", "http://a/b/c/g;x=1/y"),
    ("g;x=1/../y", "http://a/b/c/y"),
    ("g?y/./x", "http://a/b/c/g?y/./x"),
    ("g?y/../x", "http://a/b/c/g?y/../x"),
    ("g#s/./x", "http://a/b/c/g#s/./x"),
    ("g#s/../x", "http://a/b/c/g#s/../x"),
    ("http:g", "http:g"),
    ("%2E%2E/g", "http://a/b/c/%2E%2E/g"),
    ("?", "http://a/b/c/d;p?"),
    ("#", "http://a/b/c/d;p?q#"),
  ]
  for (reference, expected) in cases {
    assert_eq(
      @atom.resolve_reference(Some("http://a/b/c/d;p?q"), reference).resolved,
      expected,
    )
  }
}

///|
test "IRI resolution preserves Unicode and rejects malformed references" {
  assert_eq(
    @atom.resolve_reference(
      Some("https://example.org/目录/"),
      "../文章?q=月#节",
    ).resolved,
    "https://example.org/文章?q=月#节",
  )
  let unresolved = @atom.resolve_reference(None, "../relative")
  assert_eq(unresolved.resolved, "../relative")
  assert_true(!unresolved.is_absolute)
  for
    value in ["bad space", "%xz", "http://[broken", "a#b#c", "https://x/\\bad"] {
    let err = @test.expect_error(() => @atom.resolve_reference(None, value))
    assert_true(err is @atom.InvalidRequiredField("iri", _))
  }
}

///|
test "XML Base nesting resolves links persons generator and content src" {
  let e = entry_document(
    (
      #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.org/a/b/"><id>urn:entry:base</id><title>Base</title><updated>2003-12-13T18:30:02Z</updated><author xml:base="../people/"><name>A</name><uri xml:base="./editors/">alice</uri></author><link xml:base="../" href="./page?q=1#part"/><summary>S</summary><content xml:base="/media/" src="../file.xml?x#y" type="application/xml"/></entry>
    ),
  )
  assert_eq(e.metadata.links[0].href.raw, "./page?q=1#part")
  assert_eq(
    e.metadata.links[0].href.resolved,
    "https://example.org/a/page?q=1#part",
  )
  assert_eq(
    e.effective_authors[0].uri.unwrap().resolved,
    "https://example.org/a/people/editors/alice",
  )
  assert_eq(e.content.unwrap().src.unwrap().raw, "../file.xml?x#y")
  assert_eq(
    e.content.unwrap().src.unwrap().resolved,
    "https://example.org/file.xml?x#y",
  )
  assert_eq(e.metadata.id, Some("urn:entry:base"))
  let f = feed_document(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.org/a/"><id>urn:f</id><title>F</title><updated>2003-12-13T18:30:02Z</updated><generator xml:base="../tools/" uri="maker" version="1">Maker</generator><icon>icon.png</icon><logo xml:base="/images/">logo.svg</logo></feed>
    ),
  )
  assert_eq(
    f.metadata.generator.unwrap().uri.unwrap().resolved,
    "https://example.org/tools/maker",
  )
  assert_eq(f.metadata.icon.unwrap().resolved, "https://example.org/a/icon.png")
  assert_eq(
    f.metadata.logo.unwrap().resolved,
    "https://example.org/images/logo.svg",
  )
}

///|
test "XML Base retrieval URI and sibling scope restoration" {
  let unresolved = entry_document(
    (
      #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="../assets/"><id>urn:relative-base</id><title>Relative base</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author><content/><link xml:base="../images/" href="cover.png"/></entry>
    ),
  )
  assert_eq(unresolved.metadata.links[0].href.resolved, "../images/cover.png")
  assert_true(!unresolved.metadata.links[0].href.is_absolute)
  let input = strict_entry_xml(
    "<link xml:base='../other/' href='x'/><link rel='related' href='?q#f'/><content/>",
  )
  match
    @moonfeed.parse_atom_document_with_base(
      input, "https://example.org/a/feed.xml",
    ) {
    @atom.EntryDocument(e) => {
      assert_eq(
        e.metadata.links[0].href.resolved,
        "https://example.org/other/x",
      )
      assert_eq(
        e.metadata.links[1].href.resolved,
        "https://example.org/a/feed.xml?q#f",
      )
    }
    _ => fail("expected entry")
  }
  assert_true(
    strict_error(
      "<entry xmlns='http://www.w3.org/2005/Atom' xml:base='https://example.org/%xz'/>",
    )
    is @atom.InvalidRequiredField("xml:base", _),
  )
}

///|
test "XML Base same document references empty base and LEIRI spaces" {
  let e = entry_document(
    (
      #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.org/a/file?original#base"><id>urn:base</id><title>Base</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author><content/><link xml:base="" href="#next"/><link rel="related" xml:base="../my folder/#section" href="child?x#f"/><link rel="related" xml:base="../my^folder/&lt;section&gt;/" href="child"/></entry>
    ),
  )
  assert_eq(
    e.metadata.links[0].href.resolved,
    "https://example.org/a/file?original#next",
  )
  assert_eq(
    e.metadata.links[1].raw.base_uri,
    Some("https://example.org/my folder/#section"),
  )
  assert_eq(
    e.metadata.links[1].href.resolved,
    "https://example.org/my folder/child?x#f",
  )
  assert_eq(
    e.metadata.links[2].href.resolved,
    "https://example.org/my^folder/<section>/child",
  )
}

///|
test "XML Base preserves a character referenced LEIRI tab" {
  let e = entry_document(
    (
      #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.org/a&#x9;b/"><id>urn:entry:base-tab</id><title>Base tab</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author><link href="page"/><content>Body</content></entry>
    ),
  )
  assert_eq(e.metadata.links[0].href.resolved, "https://example.org/a\tb/page")
}

///|
test "XML language inheritance override reset and source language" {
  let f = feed_document(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en"><id>urn:f</id><title>F</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author><entry xml:lang="fr"><id>urn:e</id><title>T</title><updated>2003-12-13T18:30:02Z</updated><summary xml:lang="">S</summary><content type="html">C</content><source xml:lang="de"><title>Quelle</title></source></entry></feed>
    ),
  )
  let e = f.entries[0]
  assert_eq(f.metadata.title.unwrap().language, Some("en"))
  assert_eq(e.metadata.title.unwrap().language, Some("fr"))
  assert_eq(e.content.unwrap().language, Some("fr"))
  assert_eq(e.summary.unwrap().language, None)
  assert_eq(e.source.unwrap().title.unwrap().language, Some("de"))
}

///|
test "strict Atom validates required fields and absolute IDs" {
  for
    (extra, field) in [
      ("<title>T</title><updated>2003-12-13T18:30:02Z</updated>", "entry.id"),
      ("<id>urn:e</id><updated>2003-12-13T18:30:02Z</updated>", "entry.title"),
      ("<id>urn:e</id><title>T</title>", "entry.updated"),
    ] {
    let err = strict_error(
      "<entry xmlns='http://www.w3.org/2005/Atom'>" + extra + "</entry>",
    )
    let feed_error = strict_error(
      "<feed xmlns='http://www.w3.org/2005/Atom'>" + extra + "</feed>",
    )
    match feed_error {
      @atom.InvalidRequiredField(path, _) =>
        assert_eq(path, field.replace(old="entry.", new="feed."))
      _ => fail("wrong feed required-field error")
    }
    match err {
      @atom.InvalidRequiredField(path, _) => assert_eq(path, field)
      _ => fail("wrong error")
    }
  }
  assert_true(
    strict_error(
      "<feed xmlns='http://www.w3.org/2005/Atom'><id>relative</id><title>T</title><updated>2003-12-13T18:30:02Z</updated></feed>",
    )
    is @atom.InvalidRequiredField("feed.id", _),
  )
  let f = feed_document(
    "<feed xmlns='http://www.w3.org/2005/Atom'><id>HTTP://Example.org/%7e#</id><title/><updated>2003-12-13T18:30:02Z</updated></feed>",
  )
  assert_eq(f.metadata.id, Some("HTTP://Example.org/%7e#"))
  assert_eq(f.metadata.title.unwrap().value, "") // non-empty title is SHOULD, not MUST
}

///|
test "strict Atom rejects duplicate single metadata fields" {
  for
    extra in [
      "<id>urn:second</id>", "<title>Second</title>", "<updated>2003-12-13T18:30:02Z</updated>",
      "<rights>A</rights><rights>B</rights>", "<subtitle>A</subtitle><subtitle>B</subtitle>",
      "<generator>A</generator><generator>B</generator>", "<icon>a</icon><icon>b</icon>",
      "<logo>a</logo><logo>b</logo>",
    ] {
    assert_true(
      strict_error(strict_feed_xml(extra))
      is @atom.InvalidRequiredField(_, "duplicate element"),
    )
  }
  for
    extra in [
      "<content/><content/>", "<summary>A</summary><summary>B</summary>", "<source/><source/>",
      "<published>2003-12-13T18:30:02Z</published><published>2003-12-13T18:30:02Z</published>",
    ] {
    assert_true(
      strict_error(strict_entry_xml(extra + "<link href='x'/>"))
      is @atom.InvalidRequiredField(_, "duplicate element"),
    )
  }
}

///|
test "strict Atom author conditions and source inheritance" {
  assert_true(
    strict_error(
      "<entry xmlns='http://www.w3.org/2005/Atom'><id>urn:e</id><title>T</title><updated>2003-12-13T18:30:02Z</updated><content/></entry>",
    )
    is @atom.InvalidRequiredField("entry.author", _),
  )
  let e = entry_document(
    "<entry xmlns='http://www.w3.org/2005/Atom'><id>urn:e</id><title>T</title><updated>2003-12-13T18:30:02Z</updated><source><author><name>Source author</name></author></source><content/></entry>",
  )
  assert_eq(e.effective_authors[0].name, "Source author")
  assert_true(e.metadata.authors.is_empty())
  let f = feed_document(
    strict_feed_xml(
      "<entry><id>urn:e</id><title>T</title><updated>2003-12-13T18:30:02Z</updated><content/></entry>",
    ),
  )
  assert_eq(f.entries[0].effective_authors[0].name, "Editor")
  let own = entry_document(
    strict_entry_xml(
      "<source><author><name>S</name></author></source><content/>",
    ),
  )
  assert_eq(own.effective_authors[0].name, "A")
}

///|
test "strict Atom feed author exception requires direct authors in every entry" {
  let prefix = "<feed xmlns='http://www.w3.org/2005/Atom'><id>urn:f</id><title>F</title><updated>2003-12-13T18:30:02Z</updated>"
  let entry = "<entry><id>urn:e</id><title>T</title><updated>2003-12-13T18:30:02Z</updated>"
  let f = feed_document(
    prefix + entry + "<author><name>E</name></author><content/></entry></feed>",
  )
  assert_eq(f.entries[0].effective_authors[0].name, "E")
  assert_true(
    strict_error(
      prefix +
      entry +
      "<source><author><name>S</name></author></source><content/></entry></feed>",
    )
    is @atom.InvalidRequiredField("feed.author", _),
  )
}

///|
test "strict Atom requires alternate without content and summary for external or binary content" {
  assert_true(
    strict_error(strict_entry_xml("<summary>S</summary>"))
    is @atom.InvalidRequiredField("entry.link", _),
  )
  assert_eq(
    entry_document(strict_entry_xml("<link href=''/>")).metadata.links[0].href.raw,
    "",
  )
  assert_true(
    strict_error(strict_entry_xml("<content src='body' type='text/plain'/>"))
    is @atom.InvalidRequiredField("entry.summary", _),
  )
  assert_true(
    strict_error(strict_entry_xml("<content type='image/png'>TQ==</content>"))
    is @atom.InvalidRequiredField("entry.summary", _),
  )
  assert_eq(
    entry_document(
      strict_entry_xml("<content type='text/plain'>Body</content>"),
    ).content.unwrap().value,
    "Body",
  )
}

///|
test "strict Atom links preserve metadata and alternate uniqueness" {
  let e = entry_document(
    strict_entry_xml(
      "<link href='a' type='text/html' hreflang='en'/><link href='b' type='text/html' hreflang='fr'/><link rel='enclosure' href='audio' type='audio/mpeg' title='Audio' length='42'/><content/>",
    ),
  )
  assert_eq(e.metadata.links.length(), 3)
  assert_eq(e.metadata.links[1].hreflang, Some("fr"))
  assert_eq(e.metadata.links[2].length, Some(42UL))
  assert_eq(e.metadata.links[2].title, Some("Audio"))
  assert_true(
    strict_error(strict_entry_xml("<link href='a'/><link href='b'/><content/>"))
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  assert_true(
    strict_error(
      strict_entry_xml(
        "<link href='a' rel='http://www.iana.org/assignments/relation/alternate'/><link href='b'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  assert_true(
    strict_error(
      strict_entry_xml("<link href='a' rel='../not-a-relation'/><content/>"),
    )
    is @atom.InvalidRequiredField("entry.link[0].rel", _),
  )
}

///|
test "strict Atom dates reject lowercase whitespace RSS spellings and malformed published" {
  for
    value in [
      "2003-12-13t18:30:02Z", "2003-12-13T18:30:02z", " 2003-12-13T18:30:02Z", "Wed, 02 Oct 2002 13:00:00 GMT",
      "2003-02-30T18:30:02Z",
    ] {
    let error = strict_error(
      strict_entry_xml("<published>" + value + "</published><content/>"),
    )
    assert_true(
      match error {
        @atom.InvalidRequiredField(_, _) | @atom.InvalidDateTime(_, _) => true
        _ => false
      },
    )
  }
  let e = entry_document(
    strict_entry_xml(
      "<published>2003-12-13T20:30:02.125+02:00</published><content/>",
    ),
  )
  assert_eq(
    e.published.unwrap().unix_seconds,
    e.metadata.updated.unwrap().unix_seconds,
  )
  assert_eq(e.published.unwrap().raw, "2003-12-13T20:30:02.125+02:00")
}

///|
test "strict Atom source optional metadata and inherited rights are retained" {
  let f = feed_document(
    strict_feed_xml(
      "<rights type='html'>&lt;b&gt;Copyright&lt;/b&gt;</rights><entry><id>urn:e</id><title>E</title><updated>2003-12-13T18:30:02Z</updated><content/><source><id>urn:source</id><title>Origin</title><updated>2003-12-12T18:30:02Z</updated><category term='source' scheme='urn:scheme' label='Source label'/><contributor><name>C</name><email>c@example.org</email></contributor><generator uri='https://example.org/tool' version='1'>Tool</generator></source></entry>",
    ),
  )
  let e = f.entries[0]
  assert_eq(e.effective_rights.unwrap().value, "<b>Copyright</b>")
  let s = e.source.unwrap()
  assert_eq(s.id, Some("urn:source"))
  assert_eq(s.title.unwrap().value, "Origin")
  assert_eq(s.contributors[0].email, Some("c@example.org"))
  assert_eq(s.categories[0].label, Some("Source label"))
  assert_eq(s.categories[0].scheme.unwrap().raw, "urn:scheme")
  assert_eq(s.generator.unwrap().version, Some("1"))
  assert_true(
    strict_error(
      strict_entry_xml(
        "<source><title>A</title><title>B</title></source><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.source.title", _),
  )
}

///|
test "strict Atom person constructs enforce counts and retain extension metadata" {
  assert_true(
    strict_error(
      strict_entry_xml(
        "<contributor><uri>https://example.org</uri></contributor><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.contributor[0].name", _),
  )
  assert_true(
    strict_error(
      strict_entry_xml(
        "<contributor><name>A</name><name>B</name></contributor><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.contributor[0].name", _),
  )
  assert_true(
    strict_error(
      strict_entry_xml(
        "<contributor><name>A</name><uri>a</uri><uri>b</uri></contributor><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.contributor[0].uri", _),
  )
  let e = entry_document(
    strict_entry_xml(
      "<contributor xmlns:e='urn:ext'><name>C</name><email>c@example.org</email><e:role>Editor</e:role></contributor><category term='' label='Empty category allowed'/><content/>",
    ),
  )
  assert_eq(e.metadata.contributors[0].email, Some("c@example.org"))
  assert_eq(e.metadata.contributors[0].raw.content.length(), 3)
  assert_eq(e.metadata.categories[0].term, "")
}

///|
test "strict Atom text HTML and XHTML preserve content and validate shape" {
  let e = entry_document(
    strict_entry_xml(
      "<summary type='xhtml'><d:div xmlns:d='http://www.w3.org/1999/xhtml'>Hello <d:b>Moon</d:b> world</d:div></summary><content type='html'>&lt;p&gt;Body &amp;amp; more&lt;/p&gt;</content>",
    ),
  )
  assert_eq(e.summary.unwrap().value, "Hello Moon world")
  assert_eq(
    e.summary.unwrap().xhtml.unwrap().namespace_uri,
    Some("http://www.w3.org/1999/xhtml"),
  )
  assert_eq(e.content.unwrap().value, "<p>Body &amp; more</p>")
  for
    value in [
      "<summary type='invalid'>x</summary>", "<summary type='text'><b>x</b></summary>",
      "<summary type='html'><b>x</b></summary>", "<summary type='xhtml'><div>x</div></summary>",
      "<summary type='xhtml'><div xmlns='http://www.w3.org/1999/xhtml'/><div xmlns='http://www.w3.org/1999/xhtml'/></summary>",
    ] {
    assert_true(
      strict_error(strict_entry_xml(value + "<content/>"))
      is @atom.InvalidRequiredField(_, _),
    )
  }
}

///|
test "strict Atom content src requires empty MIME content and summary" {
  let e = entry_document(
    strict_entry_xml(
      "<summary>S</summary><content src='https://example.org/body' type='text/plain'/>",
    ),
  )
  assert_eq(
    e.content.unwrap().src.unwrap().resolved,
    "https://example.org/body",
  )
  assert_eq(e.content.unwrap().value, "")
  for
    value in [
      "<content src='body' type='text/plain'>Body</content>", "<content src='body' type='text'/>",
      "<content src='body' type='html'/>", "<content type='multipart/mixed'/>", "<content type='text/plain'><b/></content>",
    ] {
    assert_true(
      strict_error(strict_entry_xml("<summary>S</summary>" + value))
      is @atom.InvalidRequiredField(_, _),
    )
  }
}

///|
test "strict Atom MIME XML text and binary content are retained and validated" {
  let xml = entry_document(
    strict_entry_xml(
      "<content type='application/example+xml'><m:data xmlns:m='urn:data'>42</m:data></content>",
    ),
  )
  assert_eq(xml.content.unwrap().value, "42")
  assert_eq(xml.content.unwrap().markup.length(), 1)
  let text = entry_document(
    strict_entry_xml(
      "<content type='text/plain; charset=&quot;utf-8&quot;'>Plain</content>",
    ),
  )
  assert_eq(
    text.content.unwrap().media_type,
    Some("text/plain; charset=\"utf-8\""),
  )
  let binary = entry_document(
    strict_entry_xml(
      "<summary>Binary</summary><content type='image/png'>TQ==</content>",
    ),
  )
  assert_eq(binary.content.unwrap().value, "TQ==")
  assert_eq(binary.content.unwrap().decoded_bytes.unwrap(), [(77).to_byte()])
  for value in ["%%%", "TQ=", "=AAA", "A==="] {
    assert_true(
      strict_error(
        strict_entry_xml(
          "<summary>S</summary><content type='image/png'>" +
          value +
          "</content>",
        ),
      )
      is @atom.InvalidRequiredField("entry.content", _),
    )
  }
}

///|
test "strict Atom extension names signatures and duplicate entry IDs remain allowed" {
  let f = feed_document(
    strict_feed_xml(
      "<e:title xmlns:e='urn:extension'>Not title</e:title><ds:Signature xmlns:ds='http://www.w3.org/2000/09/xmldsig#'/><future xmlns='http://www.w3.org/2005/Atom'/><entry><id>urn:same</id><title>A</title><updated>2003-12-13T18:30:02Z</updated><content/></entry><entry><id>urn:same</id><title>B</title><updated>2003-12-14T18:30:02Z</updated><content/></entry>",
    ),
  )
  assert_eq(f.metadata.title.unwrap().value, "Feed")
  assert_eq(f.entries.length(), 2)
  assert_eq(f.entries[0].metadata.id, f.entries[1].metadata.id)
  assert_eq(f.metadata.raw.content.length(), 9)
}

///|
test "strict Atom malformed XML and feed metadata after entries produce typed errors" {
  assert_true(strict_error("text" + strict_feed_xml("")) is @atom.InvalidXml(_))
  assert_true(strict_error(strict_feed_xml("") + "tail") is @atom.InvalidXml(_))
  assert_true(
    strict_error("<![CDATA[ ]]>" + strict_feed_xml("")) is @atom.InvalidXml(_),
  )
  assert_true(
    strict_error(
      "<feed xmlns='http://www.w3.org/2005/Atom'><id>urn:f</id></entry>",
    )
    is @atom.InvalidXml(_),
  )
  assert_true(
    strict_error(
      strict_feed_xml(
        "<entry><id>urn:e</id><title>E</title><updated>2003-12-13T18:30:02Z</updated><content/></entry><subtitle>Late</subtitle>",
      ),
    )
    is @atom.InvalidRequiredField("feed.subtitle", _),
  )
}

///|
test "strict Atom person email quoted local parts comments and domain literals" {
  for
    email in [
      "editor@example.org", "\"a@b\" (note) @ example.org", "a.b@[127.0.0.1]",
    ] {
    let e = entry_document(
      strict_entry_xml(
        "<contributor><name>C</name><email>" +
        email +
        "</email></contributor><content/>",
      ),
    )
    assert_eq(e.metadata.contributors[0].email, Some(email))
  }
  for
    email in [
      "no-at", "a@@example.org", ".a@example.org", "a@example..org", "a@example.org trailing",
      "a@[unclosed",
    ] {
    assert_true(
      strict_error(
        strict_entry_xml(
          "<contributor><name>C</name><email>" +
          email +
          "</email></contributor><content/>",
        ),
      )
      is @atom.InvalidRequiredField("entry.contributor[0].email", _),
    )
  }
}

///|
test "strict Atom Unicode QName prefixes and XML character errors" {
  let e = entry_document(
    (
      #|<𐀀:entry xmlns:𐀀="http://www.w3.org/2005/Atom"><𐀀:id>urn:unicode</𐀀:id><𐀀:title>Unicode</𐀀:title><𐀀:updated>2003-12-13T18:30:02Z</𐀀:updated><𐀀:author><𐀀:name>A</𐀀:name></𐀀:author><𐀀:content>Body</𐀀:content></𐀀:entry>
    ),
  )
  assert_eq(e.metadata.id, Some("urn:unicode"))
  assert_eq(e.metadata.title.unwrap().value, "Unicode")
  for
    extra in [
      "<content>&#0;</content>", "<content>\u{0}</content>", "<!--bad--comment--><content/>",
      "<content a='1'b='2'/>", "<content>x]]>y</content>",
    ] {
    assert_true(strict_error(strict_entry_xml(extra)) is @atom.InvalidXml(_))
  }
}

///|
test "strict Atom content unknown external type XHTML wrapper and Base64 bytes" {
  let external = entry_document(
    strict_entry_xml("<summary>S</summary><content src='body'/>"),
  )
  assert_eq(external.content.unwrap().media_type, None)
  assert_eq(external.content.unwrap().decoded_bytes, None)
  let xhtml = entry_document(
    strict_entry_xml(
      "<content type='xhtml'><div xmlns='http://www.w3.org/1999/xhtml'><b>Bold</b></div></content>",
    ),
  )
  match xhtml.content.unwrap().markup[0] {
    @atom.MarkupContent::Element(element) => assert_eq(element.local_name, "b")
    _ => fail("XHTML div wrapper must not become content")
  }
  for
    (value, bytes) in [
      ("TQ==", [77]),
      ("TWE=", [77, 97]),
      ("TWFu", [77, 97, 110]),
    ] {
    let e = entry_document(
      strict_entry_xml(
        "<summary>S</summary><content type='application/octet-stream'>" +
        value +
        "</content>",
      ),
    )
    assert_eq(
      e.content.unwrap().decoded_bytes.unwrap().map(b => b.to_int()),
      bytes,
    )
  }
  let large = entry_document(
    strict_entry_xml(
      "<link rel='related' href='message' type='message/rfc822' length='18446744073709551616'/><content/>",
    ),
  )
  assert_eq(large.metadata.links[0].length, None)
  assert_eq(large.metadata.links[0].length_raw, Some("18446744073709551616"))
  assert_eq(large.metadata.links[0].media_type, Some("message/rfc822"))
}

///|
test "RFC4287 section1.1 Feed Document example" {
  let f = feed_document(
    (
      #|<?xml version="1.0" encoding="utf-8"?>
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|  <title>Example Feed</title><link href="http://example.org/"/>
      #|  <updated>2003-12-13T18:30:02Z</updated>
      #|  <author><name>John Doe</name></author>
      #|  <id>urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6</id>
      #|  <entry><title>Atom-Powered Robots Run Amok</title>
      #|    <link href="http://example.org/2003/12/13/atom03"/>
      #|    <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
      #|    <updated>2003-12-13T18:30:02Z</updated><summary>Some text.</summary>
      #|  </entry>
      #|</feed>
    ),
  )
  assert_eq(f.metadata.title.unwrap().value, "Example Feed")
  assert_eq(f.entries[0].effective_authors[0].name, "John Doe")
  assert_eq(f.entries[0].summary.unwrap().value, "Some text.")
  assert_eq(
    f.entries[0].metadata.links[0].href.resolved,
    "http://example.org/2003/12/13/atom03",
  )
}

///|
test "strict Atom dates preserve fractions year zero known leap seconds and unknown offset" {
  let leap = entry_document(
    strict_entry_xml(
      "<published>2017-01-01T00:59:60.123456789+01:00</published><content/>",
    ),
  )
  let date = leap.published.unwrap()
  assert_true(date.leap_second)
  assert_eq(date.fractional_digits, Some("123456789"))
  assert_eq(date.unix_seconds, 1483228800L)
  let zero = entry_document(
    strict_entry_xml("<published>0000-02-29T00:00:00Z</published><content/>"),
  )
  assert_eq(zero.published.unwrap().unix_seconds, -62162121600L)
  let unknown = entry_document(
    strict_entry_xml(
      "<published>2003-12-13T18:30:02-00:00</published><content/>",
    ),
  )
  assert_true(unknown.published.unwrap().unknown_local_offset)
  assert_eq(unknown.published.unwrap().unix_seconds, 1071340202L)
  assert_true(
    strict_error(
      strict_entry_xml("<published>2015-12-31T23:59:60Z</published><content/>"),
    )
    is @atom.InvalidRequiredField("entry.published", _),
  )
}

///|
test "strict Atom rejects a leap second absent from the current IERS table" {
  assert_true(
    strict_error(
      strict_entry_xml("<published>2026-12-31T23:59:60Z</published><content/>"),
    )
    is @atom.InvalidRequiredField("entry.published", _),
  )
}
