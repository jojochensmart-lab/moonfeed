///|
test "final review legal forward empty references share the whole Reader budget" {
  let xml = "<!DOCTYPE x [<!ENTITY a '&b;'><!ENTITY b ''>]><x a='&a;'>&a;</x>"
  // One declaration reference, then two in the attribute and two in text.
  let exact = reader_with_limits(xml, { ..xml_limits(), references: 5, })
  assert_true(
    exact.read_event() is Start({ attributes, .. }) &&
    attributes.get("a") == Some(""),
  )
  assert_true(exact.read_event() is Text(""))
  assert_true(exact.read_event() is End("x"))
  assert_true(exact.read_event() is Eof)
  let limited = reader_with_limits(xml, { ..xml_limits(), references: 4, })
  assert_true(limited.read_event() is Start(_))
  assert_true(
    @test.expect_error(() => limited.read_event())
    is Malformed("XML entity reference limit exceeded"),
  )
}

///|
test "final review NamespaceReader cannot reset inner entity budgets" {
  let xml = "<!DOCTYPE x [<!ENTITY a '&b;'><!ENTITY b ''>]><x xmlns='urn:test' a='&a;'>&a;</x>"
  let reader : NamespaceReader = {
    inner: reader_with_limits(xml, { ..xml_limits(), references: 4, }),
    scopes: [],
  }
  assert_true(
    reader.read_event()
    is NamespaceStart(
      { name: { namespace_uri: Some("urn:test"), local_name: "x", }, .. }
    ),
  )
  assert_true(
    @test.expect_error(() => reader.read_event())
    is Malformed("XML entity reference limit exceeded"),
  )
}
