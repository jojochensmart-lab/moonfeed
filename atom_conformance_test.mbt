///|
fn conform_entry(input : String) -> @atom.AtomEntry raise {
  match @moonfeed.parse_atom_document(input) {
    @atom.EntryDocument(e) => e
    _ => fail("expected Entry Document")
  }
}

///|
fn conform_error(input : String) -> @atom.ParseError raise {
  @test.expect_error(() => @moonfeed.parse_atom_document(input))
}

///|
test "conformance RFC4287 Feed fields and inherited author" {
  match @moonfeed.parse_atom_document(@conformance.rfc_feed) {
    @atom.FeedDocument(f) => {
      assert_eq(f.metadata.title.unwrap().value, "Example Feed")
      assert_eq(f.entries.length(), 1)
      assert_eq(f.entries[0].effective_authors[0].name, "John Doe")
      assert_eq(f.entries[0].summary.unwrap().value, "Some text.")
      assert_eq(f.entries[0].metadata.links[0].rel, "alternate")
    }
    _ => fail("expected Feed Document")
  }
}

///|
test "conformance prefixed Entry source bases languages XHTML and extension" {
  let e = conform_entry(@conformance.scoped_entry)
  assert_eq(e.metadata.id, Some("URN:entry:%7e"))
  assert_eq(e.metadata.title.unwrap().language, Some("zh-Hant"))
  assert_eq(e.summary.unwrap().language, None)
  assert_eq(
    e.effective_authors[0].uri.unwrap().resolved,
    "https://example.org/a/source/person",
  )
  assert_eq(e.metadata.links[0].href.raw, "./story?edition=2#part")
  assert_eq(
    e.metadata.links[0].href.resolved,
    "https://example.org/a/story?edition=2#part",
  )
  assert_eq(e.content.unwrap().value, "A B")
  assert_eq(e.content.unwrap().language, Some("en-US"))
  assert_eq(e.metadata.raw.local_name, "entry")
}

///|
test "conformance RFC3066 language syntax accepts private historic and boundary tags" {
  for
    tag in [
      "en", "EN-us", "zh-Hant-TW", "i-klingon", "x-private", "abcdefgh-12345678",
      "de-1996", "qaa-Qaaa-QM",
    ] {
    let e = conform_entry(
      @conformance.entry("xml:lang='" + tag + "'", "<content/>"),
    )
    assert_eq(e.metadata.title.unwrap().language, Some(tag))
  }
  let e = conform_entry(@conformance.entry("xml:lang=''", "<content/>"))
  assert_eq(e.metadata.title.unwrap().language, None)
}

///|
test "conformance invalid language tags have typed diagnostics" {
  for
    tag in [
      "en_US", "1en", "en-", "-en", "en--US", "abcdefghi", "en-123456789", "en US",
      "中文",
    ] {
    assert_true(
      conform_error(@conformance.entry("xml:lang='" + tag + "'", "<content/>"))
      is @atom.InvalidRequiredField("xml:lang", _),
    )
  }
  assert_true(
    conform_error(@conformance.entry("", "<content xml:lang='en_US'/>"))
    is @atom.InvalidRequiredField("xml:lang", _),
  )
}

///|
test "conformance hreflang grammar and case insensitive alternate identity" {
  for tag in ["", "en_US", "en-"] {
    assert_true(
      conform_error(
        @conformance.entry(
          "",
          "<link href='x' hreflang='" + tag + "'/><content/>",
        ),
      )
      is @atom.InvalidRequiredField("entry.link[0].hreflang", _),
    )
  }
  assert_true(
    conform_error(
      @conformance.entry(
        "", "<link href='x' hreflang='en-US'/><link href='y' hreflang='EN-us'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
}

///|
test "conformance legacy normalization remains permissive" {
  assert_eq(@moonfeed.parse_atom(@conformance.legacy_feed).items[0].id, "item")
  assert_eq(@moonfeed.parse(@conformance.legacy_feed).title, "Legacy")
  assert_true(
    conform_error(@conformance.legacy_feed)
    is @atom.InvalidRequiredField("xml:lang", _),
  )
}

///|
test "conformance XML physical line endings differ from numeric references" {
  let e = conform_entry(
    @conformance.entry("", "<content>A\r\nB\rC&#13;D&#xA;E</content>"),
  )
  assert_eq(e.content.unwrap().value, "A\nB\nC\rD\nE")
}

///|
test "conformance XML attribute normalization preserves reference whitespace" {
  let e = conform_entry(
    @conformance.entry(
      "", "<link href='x' title='A\tB\r\nC&#x9;D&#13;E&#10;F'/><content/>",
    ),
  )
  assert_eq(e.metadata.links[0].title, Some("A B C\tD\rE\nF"))
}

///|
test "conformance XML declarations validate version order encoding and position" {
  let input = @conformance.entry("", "<content/>")
  let e = conform_entry(
    "<?xml version='1.0' encoding='UTF-8' standalone='yes'?>" + input,
  )
  assert_eq(e.metadata.id, Some("urn:conformance"))
  for
    declaration in [
      "<?xml?>", "<?xml version='1.1'?>", "<?xml encoding='utf-8' version='1.0'?>",
      "<?xml version='1.0' standalone='maybe'?>", "<?xml version='1.0' encoding='8utf'?>",
      " <?xml version='1.0'?>", "<!--comment--><?xml version='1.0'?>", "<?XML version='1.0'?>",
    ] {
    assert_true(conform_error(declaration + input) is @atom.InvalidXml(_))
  }
  assert_true(
    conform_error(@conformance.entry("", "<?xml version='1.0'?><content/>"))
    is @atom.InvalidXml(_),
  )
}

///|
test "conformance general processing instructions and comments are skipped" {
  let e = conform_entry(
    "<?xml-stylesheet href='view.xsl'?>" +
    @conformance.entry(
      "", "<!--ok--><?app payload?><content>A&amp;B&#x1F680;</content>",
    ) +
    "<?done?>",
  )
  assert_eq(e.content.unwrap().value, "A&B🚀")
  assert_true(
    conform_error(@conformance.entry("", "<?1bad?><content/>"))
    is @atom.InvalidXml(_),
  )
}

///|
test "conformance namespace identity is literal after XML entity decoding" {
  let body = "<id>urn:x</id><title>X</title><updated>2003-12-13T18:30:02Z</updated><author><name>A</name></author><content/>"
  let e = conform_entry(
    "<entry xmlns='http://www.w3.org/2005/&#65;tom'>" + body + "</entry>",
  )
  assert_eq(e.metadata.title.unwrap().value, "X")
  for
    uri in [
      "HTTP://www.w3.org/2005/Atom", "http://www.w3.org/2005/%41tom", "http://www.w3.org/2005/./Atom",
    ] {
    let error = conform_error("<entry xmlns='" + uri + "'>" + body + "</entry>")
    if !(error is @atom.InvalidAtomRoot(_)) {
      fail(uri)
    }
  }
}

///|
test "conformance namespace lexical errors reserved bindings and expanded duplicates" {
  for
    attributes in [
      "xmlns:e='urn:bad space'", "xmlns:e='urn:%GG'", "xmlns:e='urn:x#one#two'",
      "xmlns:xml='urn:wrong'", "xmlns:e='http://www.w3.org/2000/xmlns/'", "xmlns:a='urn:x' xmlns:b='urn:x' a:key='1' b:key='2'",
      "e:unknown='1'", "1bad='x'",
    ] {
    assert_true(
      conform_error(@conformance.entry(attributes, "<content/>"))
      is @atom.InvalidXml(_),
    )
  }
  let e = conform_entry(
    @conformance.entry("xmlns:e='relative' e:key='value'", "<content/>"),
  )
  assert_eq(e.metadata.raw.attributes[0].namespace_uri, Some("relative"))
}

///|
test "conformance IRI IPv6 and IPvFuture literals" {
  for
    host in [
      "[::]", "[::1]", "[2001:db8::1]", "[1:2:3:4:5:6:7:8]", "[::ffff:192.0.2.1]",
      "[v1.a:b]",
    ] {
    let href = "https://" + host + "/path"
    let e = conform_entry(
      @conformance.entry("", "<link href='" + href + "'/><content/>"),
    )
    assert_eq(e.metadata.links[0].href.resolved, href)
  }
  for
    host in [
      "[x:y]", "[1:2:3]", "[1:2:3:4:5:6:7:8::]", "[:::1]", "[::1:]", "[::ffff:999.1.1.1]",
      "[v.a]", "[v1.]", "[v1.%20]",
    ] {
    assert_true(
      conform_error(
        @conformance.entry("", "<link href='https://" + host + "/'/><content/>"),
      )
      is @atom.InvalidRequiredField("entry.link[0].href", _),
    )
  }
}

///|
test "conformance RFC3987 private use is query only" {
  let href = "https://例え.example/路径?q=\u{E000}"
  let e = conform_entry(
    @conformance.entry("", "<link href='" + href + "'/><content/>"),
  )
  assert_eq(e.metadata.links[0].href.raw, href)
  for
    href in [
      "https://example.org/\u{E000}", "https://example.org/#\u{E000}", "https://example.org/\u{FDD0}",
      "https://example.org/\u{1FFFF}", "https://example.org/\u{FFF0}", "https://example.org/\u{10FFFE}",
      "https://example.org/\u{9F}", "https://\u{E000}@example.org/path",
    ] {
    assert_true(
      conform_error(
        @conformance.entry("", "<link href='" + href + "'/><content/>"),
      )
      is @atom.InvalidRequiredField("entry.link[0].href", _),
    )
  }
}

///|
test "conformance RFC3987 component productions" {
  for
    value in [
      "https://user:pass@example.org:443/a!$&'()*+,;=:@segment?query=!$&'()*+,;=:@/?#fragment?/?",
      "https://用户@例え.example/路径?q=月#节", "../relative/路径?q=值",
      "https://host/%E2%9C%93", "https://host/\u{A0}/\u{D7FF}/\u{FDCF}/\u{FDF0}/\u{FFEF}/\u{10000}/\u{DFFFD}/\u{E1000}/\u{EFFFD}",
      "https://host/?q=\u{E000}\u{F0000}\u{100000}",
    ] {
    assert_eq(@atom.resolve_reference(None, value).resolved, value)
  }
  for
    value in [
      "https://user[name]@example.org/path", "https://bad^host/path", "https://example.org/path\\tail",
      "https://example.org/path?bad[query]",
    ] {
    assert_true(
      @test.expect_error(() => @atom.resolve_reference(None, value))
      is @atom.InvalidRequiredField("iri", _),
    )
  }
}

///|
test "conformance MIME comments folding and parameter comparison" {
  let e = conform_entry(
    @conformance.entry(
      "", "<content type='(note) TEXT (major) / PLAIN ; CHARSET = &quot;UTF-8&quot; (end)'>Body</content>",
    ),
  )
  assert_eq(e.content.unwrap().value, "Body")
  assert_eq(
    e.content.unwrap().media_type,
    Some("(note) TEXT (major) / PLAIN ; CHARSET = \"UTF-8\" (end)"),
  )
  assert_true(
    conform_error(
      @conformance.entry(
        "", "<link href='a' type='TEXT/HTML; Charset=UTF-8; profile=abc'/><link href='b' type='text/html;PROFILE=&quot;abc&quot;;charset=&quot;utf-8&quot;'/><content/>",
      ),
    )
    is @atom.InvalidRequiredField("entry.link[1]", _),
  )
  let folded = conform_entry(
    @conformance.entry(
      "", "<content type='text/plain;&#13;&#10; charset=utf-8'>Fold</content>",
    ),
  )
  assert_eq(folded.content.unwrap().value, "Fold")
}

///|
test "conformance MIME parameter values are not discarded or universally case folded" {
  let e = conform_entry(
    @conformance.entry(
      "", "<link href='a' type='application/example; profile=ABC'/><link href='b' type='application/example; profile=abc'/><content/>",
    ),
  )
  assert_eq(e.metadata.links.length(), 2)
  assert_eq(
    e.metadata.links[0].media_type,
    Some("application/example; profile=ABC"),
  )
  for
    media in [
      "plain", "text/plain;", "text/plain; a=", "text/plain; a=&quot;x", "text/plain&#10;x",
      "text/plain; a=é",
    ] {
    assert_true(
      conform_error(
        @conformance.entry("", "<content type='" + media + "'>X</content>"),
      )
      is @atom.InvalidRequiredField("entry.content.type", _),
    )
  }
}

///|
test "conformance email folding and malformed line breaks" {
  let e = conform_entry(
    @conformance.entry(
      "", "<contributor><name>B</name><email>(note) a&#13;&#10; @example.org</email></contributor><content/>",
    ),
  )
  assert_eq(e.metadata.contributors[0].email, Some("(note) a\r\n @example.org"))
  let obsolete = conform_entry(
    @conformance.entry(
      "", "<contributor><name>Old syntax</name><email>(lead) a (left) . (right) &quot;b c&quot; @ (at) example (dot) . (name) org (tail)</email></contributor><content/>",
    ),
  )
  assert_eq(
    obsolete.metadata.contributors[0].email,
    Some(
      "(lead) a (left) . (right) \"b c\" @ (at) example (dot) . (name) org (tail)",
    ),
  )
  let folded_obsolete = conform_entry(
    @conformance.entry(
      "", "<contributor><name>Folded old syntax</name><email>a.&#13;&#10; b@example.&#13;&#10; org</email></contributor><content/>",
    ),
  )
  assert_eq(
    folded_obsolete.metadata.contributors[0].email,
    Some("a.\r\n b@example.\r\n org"),
  )
  for
    value in [
      "a&#10;@example.org", "a&#13;@example.org", "a&#13;&#10;@example.org", "a..b@example.org",
    ] {
    assert_true(
      conform_error(
        @conformance.entry(
          "",
          "<contributor><name>B</name><email>" +
          value +
          "</email></contributor><content/>",
        ),
      )
      is @atom.InvalidRequiredField("entry.contributor[0].email", _),
    )
  }
  let mut nested_comment = ""
  let mut closing_comment = ""
  for i = 0; i < 64; i = i + 1 {
    nested_comment += "("
    closing_comment += ")"
  }
  let deep_email = nested_comment +
    "comment" +
    closing_comment +
    "x@example.org"
  let deep = conform_entry(
    @conformance.entry(
      "",
      "<contributor><name>X</name><email>" +
      deep_email +
      "</email></contributor><content/>",
    ),
  )
  assert_eq(deep.metadata.contributors[0].email, Some(deep_email))
}

///|
test "conformance retrieval base content src and specific negative paths" {
  match
    @moonfeed.parse_atom_document_with_base(
      @conformance.entry(
        "xml:base='../'", "<summary>S</summary><content src='./body?x=1#f' type='application/json'/>",
      ),
      "https://example.org/feeds/current.atom",
    ) {
    @atom.EntryDocument(e) =>
      assert_eq(
        e.content.unwrap().src.unwrap().resolved,
        "https://example.org/body?x=1#f",
      )
    _ => fail("expected Entry")
  }
  assert_true(
    conform_error(@conformance.entry("", "<title>Duplicate</title><content/>"))
    is @atom.InvalidRequiredField("entry.title", _),
  )
  assert_true(
    conform_error(@conformance.entry("", "<content src='body'/>"))
    is @atom.InvalidRequiredField("entry.summary", _),
  )
}

///|
test "conformance malformed XML cannot be hidden in foreign extensions" {
  for
    body in [
      "<ext:x xmlns:ext='urn:x'>&#xD800;</ext:x><content/>", "<content>&#xFFFE;</content>",
      "<content>&unknown;</content>", "<content a='1' a='2'/>", "<content><x></content>",
      "<!DOCTYPE entry><content/>",
    ] {
    assert_true(
      conform_error(@conformance.entry("", body)) is @atom.InvalidXml(_),
    )
  }
}

///|
test "conformance shared XML normalization retains RSS behavior and text entities" {
  let feed = @moonfeed.parse_rss(
    "<rss version='2.0'><channel><title>News</title><link>https://example.org/</link><description>A\r\nB&#13;C &amp; D</description></channel></rss>",
  )
  assert_eq(feed.title, "News")
  assert_eq(feed.description, Some("A\nB\rC & D"))
  let e = conform_entry(
    @conformance.entry(
      "", "<content type='text/x-example{v}; p=&quot;a\\&quot;b&quot;'>Text</content>",
    ),
  )
  assert_eq(e.content.unwrap().value, "Text")
}

///|
test "conformance namespace URI reference component grammar" {
  for
    uri in [
      "urn:example:feed", "https://example.org/ns?q=a/b#part", "../relative/ns",
      "//example.org/ns", "https://user:pass@example.org:443/ns", "http://[2001:db8::1]/ns",
      "http://[::ffff:192.0.2.128]/ns", "http://[v1.future-host]/ns", "a/b:c?d/e#f",
    ] {
    let e = conform_entry(
      @conformance.entry("xmlns:e='" + uri + "' e:child='ok'", "<content/>"),
    )
    assert_eq(e.metadata.raw.attributes.length(), 1)
  }
  for
    uri in [
      "1invalid:scheme", "urn:bad[bracket", "urn:bad]bracket", "//example.org:abc/ns",
      "//example.org/[path]", "//user@@example.org/ns", "http://example.org:8x/ns",
      "urn:bad?q=[x]", "urn:bad#frag[x]", "http://[2001::db8::1]/ns", "http://[1:2:3:4:5:6:7]/ns",
      "http://[vG.future]/ns", "http://[v1.]/ns",
    ] {
    assert_true(
      conform_error(@conformance.entry("xmlns:e='" + uri + "'", "<content/>"))
      is @atom.InvalidXml(_),
    )
  }
}
