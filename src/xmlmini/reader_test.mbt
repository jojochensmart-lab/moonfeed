///|
fn xml_events(
  input : String,
) -> Array[@xmlmini.XmlEvent] raise @xmlmini.XmlError {
  let reader = @xmlmini.Reader::from_string(input)
  let result = []
  while true {
    let event = reader.read_event()
    result.push(event)
    if event is @xmlmini.Eof {
      break
    }
  }
  result
}

///|
fn xml_error(input : String) -> Bool {
  try {
    let _ = xml_events(input)
    false
  } catch {
    @xmlmini.Malformed(_) => true
  }
}

///|
test "xmlmini declaration comments nested and prefixed names" {
  let events = xml_events(
    "<?xml version=\"1.0\"?><!--lead--><rss><content:encoded>ok</content:encoded></rss>",
  )
  @test.assert_eq(events.length(), 6)
  assert_true(events[0] is @xmlmini.Start(_))
  assert_true(events[1] is @xmlmini.Start(_))
  match events[1] {
    @xmlmini.Start(element) => @test.assert_eq(element.name, "content:encoded")
    _ => assert_true(false)
  }
  assert_true(events[2] is @xmlmini.Text("ok"))
  assert_true(events[3] is @xmlmini.End("content:encoded"))
  assert_true(events[4] is @xmlmini.End("rss"))
  assert_true(events[5] is @xmlmini.Eof)
}

///|
test "xmlmini self closing attributes and basic entities" {
  let events = xml_events(
    "<item url='a&amp;b' type=\"audio&quot;x\" empty=\"\"/>",
  )
  match events[0] {
    @xmlmini.Empty(element) => {
      @test.assert_eq(element.name, "item")
      @test.assert_eq(element.attributes.get("url"), Some("a&b"))
      @test.assert_eq(element.attributes.get("type"), Some("audio\"x"))
      @test.assert_eq(element.attributes.get("empty"), Some(""))
    }
    _ => assert_true(false)
  }
}

///|
test "xmlmini CDATA and decimal and hexadecimal entities" {
  let events = xml_events("<x>a&#65;&#x1F319;<![CDATA[<b>raw</b>]]></x>")
  assert_true(events[1] is @xmlmini.Text("aA🌙"))
  assert_true(events[2] is @xmlmini.CData("<b>raw</b>"))
  let apostrophe = xml_events("<x>&apos;</x>")
  assert_true(apostrophe[1] is @xmlmini.Text("'"))
}

///|
test "xmlmini rejects malformed and mismatched XML" {
  assert_true(xml_error("<x>"))
  assert_true(xml_error("<x></y>"))
  assert_true(xml_error("<x>&unknown;</x>"))
}

///|
test "xmlmini expands internal DTD entities and supplies declared defaults" {
  let events = xml_events(
    "<!DOCTYPE root [<!ENTITY greeting 'hello &amp; world'><!ENTITY nested 'said: &greeting;'><!ATTLIST root mode NMTOKENS '  one   two  ' label CDATA '&greeting;' image NOTATION (gif | jpeg) ' jpeg '>]><root>&nested;</root>",
  )
  match events[0] {
    @xmlmini.Start(element) => {
      @test.assert_eq(element.attributes.get("mode"), Some("one two"))
      @test.assert_eq(element.attributes.get("label"), Some("hello & world"))
      @test.assert_eq(element.attributes.get("image"), Some("jpeg"))
    }
    _ => assert_true(false)
  }
  assert_true(events[1] is @xmlmini.Text("said: hello & world"))
  assert_true(events[2] is @xmlmini.End("root"))
}

///|
test "xmlmini DTD defaults participate in namespace expansion without fetching external subsets" {
  let events = namespace_events(
    "<!DOCTYPE feed SYSTEM 'https://invalid.example/feed.dtd' [<!ATTLIST feed xmlns CDATA 'urn:atom'>]><feed><entry/></feed>",
  )
  match events[0] {
    @xmlmini.NamespaceStart(element) => {
      @test.assert_eq(element.name.namespace_uri, Some("urn:atom"))
      @test.assert_eq(element.name.local_name, "feed")
    }
    _ => assert_true(false)
  }
  match events[1] {
    @xmlmini.NamespaceEmpty(element) =>
      @test.assert_eq(element.name.namespace_uri, Some("urn:atom"))
    _ => assert_true(false)
  }
}

///|
test "xmlmini rejects recursive and markup general entities and misplaced DTDs" {
  assert_true(
    xml_error("<!DOCTYPE x [<!ENTITY a '&b;'><!ENTITY b '&a;'>]><x>&a;</x>"),
  )
  assert_true(xml_error("<!DOCTYPE x [<!ENTITY a '<b/>'>]><x>&a;</x>"))
  assert_true(xml_error("<x/><!DOCTYPE x>"))
  assert_true(
    xml_error("<!DOCTYPE x [<!ENTITY ext SYSTEM 'urn:external'>]><x>&ext;</x>"),
  )
  assert_true(xml_error("<!DOCTYPE x [<!ENTITY % p 'unused'>%p;]><x/>"))
  assert_true(xml_error("<!DOCTYPE x [<!-- invalid -- comment -->]><x/>"))
  assert_true(xml_error("<!DOCTYPE x [<!UNKNOWN invalid>]><x/>"))
}

///|
test "xmlmini bounds nested internal entity expansion" {
  let mut subset = "<!ENTITY e0 'x'>"
  let mut previous = "e0"
  for index = 1; index <= 21; index = index + 1 {
    let current = "e" + index.to_string()
    subset = subset +
      "<!ENTITY " +
      current +
      " '&" +
      previous +
      ";&" +
      previous +
      ";'>"
    previous = current
  }
  assert_true(
    xml_error("<!DOCTYPE x [" + subset + "]><x>&" + previous + ";</x>"),
  )
}

///|
test "xmlmini skips comments between events" {
  let events = xml_events("<x><!--inside--><y/></x>")
  @test.assert_eq(events.length(), 4)
  assert_true(events[0] is @xmlmini.Start(_))
  assert_true(events[1] is @xmlmini.Empty(_))
  assert_true(events[2] is @xmlmini.End("x"))
}

///|
fn namespace_events(
  input : String,
) -> Array[@xmlmini.NamespaceEvent] raise @xmlmini.XmlError {
  let reader = @xmlmini.NamespaceReader::from_string(input)
  let result = []
  while true {
    let event = reader.read_event()
    result.push(event)
    if event is @xmlmini.NamespaceEof {
      break
    }
  }
  result
}

///|
fn namespace_error(input : String) -> Bool {
  try {
    let _ = namespace_events(input)
    false
  } catch {
    @xmlmini.Malformed(_) => true
  }
}

///|
test "xmlmini expands default and arbitrary prefixed names and attributes" {
  let events = namespace_events(
    "<root xmlns='urn:root' xmlns:p='urn:attribute' id='plain' p:id='qualified'><child xmlns=''/><p:child/></root>",
  )
  match events[0] {
    @xmlmini.NamespaceStart(element) => {
      @test.assert_eq(element.name.namespace_uri, Some("urn:root"))
      @test.assert_eq(element.name.local_name, "root")
      @test.assert_eq(element.attributes.length(), 2)
      @test.assert_eq(element.attributes[0].name.namespace_uri, None)
      @test.assert_eq(
        element.attributes[1].name.namespace_uri,
        Some("urn:attribute"),
      )
    }
    _ => assert_true(false)
  }
  match events[1] {
    @xmlmini.NamespaceEmpty(element) =>
      @test.assert_eq(element.name.namespace_uri, None)
    _ => assert_true(false)
  }
  match events[2] {
    @xmlmini.NamespaceEmpty(element) =>
      @test.assert_eq(element.name.namespace_uri, Some("urn:attribute"))
    _ => assert_true(false)
  }
}

///|
test "xmlmini namespace rebinding is scoped and default namespace can reset" {
  let events = namespace_events(
    "<p:root xmlns:p='urn:one' xmlns='urn:default'><p:outer><p:inner xmlns:p='urn:two'><inner xmlns=''/></p:inner><p:after/></p:outer></p:root>",
  )
  match (events[0], events[1], events[2], events[3], events[5]) {
    (
      @xmlmini.NamespaceStart(root),
      @xmlmini.NamespaceStart(outer),
      @xmlmini.NamespaceStart(inner),
      @xmlmini.NamespaceEmpty(reset),
      @xmlmini.NamespaceEmpty(after),
    ) => {
      @test.assert_eq(root.name.namespace_uri, Some("urn:one"))
      @test.assert_eq(outer.name.namespace_uri, Some("urn:one"))
      @test.assert_eq(inner.name.namespace_uri, Some("urn:two"))
      @test.assert_eq(reset.name.namespace_uri, None)
      @test.assert_eq(after.name.namespace_uri, Some("urn:one"))
    }
    _ => assert_true(false)
  }
}

///|
test "xmlmini rejects undeclared prefixes reserved bindings and expanded duplicates" {
  assert_true(namespace_error("<p:root/>"))
  assert_true(namespace_error("<root xmlns:xml='urn:wrong'/>"))
  assert_true(
    namespace_error(
      "<root xmlns:a='urn:same' xmlns:b='urn:same' a:id='1' b:id='2'/>",
    ),
  )
  assert_true(namespace_error("<root xmlns:xmlns='urn:bad'/>"))
}
