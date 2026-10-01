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
test "xmlmini skips comments between events" {
  let events = xml_events("<x><!--inside--><y/></x>")
  @test.assert_eq(events.length(), 4)
  assert_true(events[0] is @xmlmini.Start(_))
  assert_true(events[1] is @xmlmini.Empty(_))
  assert_true(events[2] is @xmlmini.End("x"))
}
