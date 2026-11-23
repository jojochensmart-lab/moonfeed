///|
fn document_error(input : String) -> @xmlmini.XmlError raise {
  @test.expect_error(() => xml_events(input))
}

///|
test "XML document permits only whitespace comments and PI around its root" {
  let events = xml_events(
    " \t\r\n<!--before--><?audit before?><root><child/></root><?audit complete?><!--tail-->\r\n",
  )
  assert_eq(events.length(), 6)
  assert_true(events[0] is @xmlmini.Text(" \t\n"))
  assert_true(events[1] is @xmlmini.Start({ name: "root", .. }))
  assert_true(events[2] is @xmlmini.Empty({ name: "child", .. }))
  assert_true(events[3] is @xmlmini.End("root"))
  assert_true(events[4] is @xmlmini.Text("\n"))
  assert_true(events[5] is @xmlmini.Eof)
}

///|
test "XML reader rejects ordinary characters before the root" {
  assert_true(
    document_error("INVALID<root/>")
    is @xmlmini.Malformed("character data outside document element"),
  )
}

///|
test "XML reader rejects ordinary characters after the root" {
  assert_true(
    document_error("<root/>INVALID")
    is @xmlmini.Malformed("character data outside document element"),
  )
}

///|
test "XML reader requires exactly one root for empty and paired elements" {
  for
    input in [
      "<one/><two/>", "<one></one><two/>", "<one/><!--between--><two></two>",
    ] {
    assert_true(
      document_error(input) is @xmlmini.Malformed("multiple document elements"),
    )
  }
}

///|
test "XML reader rejects documents without a document element" {
  for
    input in [
      "", " \t\r\n", "<!--only comment-->", "<?audit complete?>", "<?xml version='1.0'?>",
    ] {
    assert_true(
      document_error(input) is @xmlmini.Malformed("missing document element"),
    )
  }
}

///|
test "XML Misc excludes CDATA references and non XML whitespace" {
  for
    outside in [
      "<![CDATA[]]>", "<![CDATA[ ]]>", "&#32;", "&#xA;", "&amp;", "\u{A0}",
    ] {
    assert_true(document_error(outside + "<root/>") is @xmlmini.Malformed(_))
    assert_true(document_error("<root/>" + outside) is @xmlmini.Malformed(_))
  }
  let events = xml_events("<root>&#32;<![CDATA[ ]]></root>")
  assert_true(events[1] is @xmlmini.Text(" "))
  assert_true(events[2] is @xmlmini.CData(" "))
}

///|
test "XML reader checks incomplete markup after its root" {
  for tail in ["<", "<unfinished", "</root>", "<!DOCTYPE root>"] {
    assert_true(document_error("<root/>" + tail) is @xmlmini.Malformed(_))
  }
}

///|
test "XML reader validates comments after its root" {
  for tail in ["<!--unclosed", "<!--invalid -- comment-->", "<!--invalid--->"] {
    assert_true(document_error("<root/>" + tail) is @xmlmini.Malformed(_))
  }
  let events = xml_events("<root/><!--valid-->")
  assert_eq(events.length(), 2)
  assert_true(events[0] is @xmlmini.Empty({ name: "root", .. }))
  assert_true(events[1] is @xmlmini.Eof)
}

///|
test "XML reader validates processing instructions after its root" {
  for
    tail in [
      "<?audit incomplete", "<??>", "<?audit!?>", "<?XML data?>", "<?xml version='1.0'?>",
    ] {
    assert_true(document_error("<root/>" + tail) is @xmlmini.Malformed(_))
  }
  let events = xml_events("<root/><?audit complete?><?audit?>")
  assert_eq(events.length(), 2)
  assert_true(events[0] is @xmlmini.Empty({ name: "root", .. }))
  assert_true(events[1] is @xmlmini.Eof)
}

///|
test "namespace reader inherits document checks from the common XML reader" {
  let xml = "<a:root xmlns:a='urn:root'/>"
  let events = namespace_events("<!--lead-->" + xml + "<?audit complete?>")
  assert_eq(events.length(), 2)
  assert_true(
    events[0]
    is @xmlmini.NamespaceEmpty(
      { name: { namespace_uri: Some("urn:root"), local_name: "root", }, .. }
    ),
  )
  assert_true(events[1] is @xmlmini.NamespaceEof)
  for input in ["INVALID" + xml, xml + "INVALID", xml + "<other/>"] {
    assert_true(
      @test.expect_error(() => namespace_events(input)) is @xmlmini.Malformed(_),
    )
  }
}
