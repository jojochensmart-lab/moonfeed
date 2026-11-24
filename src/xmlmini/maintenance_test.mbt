///|
test "maintenance XML BOM UTF8 declaration Unicode names and characters" {
  let events = xml_events(
    "\u{FEFF}<?xml version='1.0' encoding='UTF-8'?><𐀀 value='中文'>🌙&#x10FFFF;</𐀀>",
  )
  assert_true(events[0] is @xmlmini.Start({ name: "𐀀", .. }))
  assert_true(events[1] is @xmlmini.Text("🌙\u{10FFFF}"))
  assert_true(events[2] is @xmlmini.End("𐀀"))
  assert_true(events[3] is @xmlmini.Eof)
}

///|
test "maintenance XML rejects invalid characters even in unused DTD constructs" {
  for
    input in [
      "<!DOCTYPE x [<!ENTITY unused '\u{0}'>]><x/>", "<!DOCTYPE x [<!-- \u{1} -->]><x/>",
      "<!DOCTYPE x SYSTEM 'bad\u{0}id'><x/>", "<!DOCTYPE x [<?audit \u{8}?>]><x/>",
    ] {
    assert_true(xml_error(input))
  }
}

///|
test "maintenance XML attribute declarations validate types and enumeration grammar" {
  for
    declaration in [
      "value GARBAGE 'a'", "value () 'a'", "value (a||b) 'a'", "value ((a)) 'a'",
      "value NOTATION (1bad) 'a'", "value CDATA '<bad'", "value CDATA '&#0;'", "value CDATA '&bad'",
    ] {
    assert_true(
      xml_error("<!DOCTYPE x [<!ATTLIST x " + declaration + ">]><x/>"),
    )
  }
  let events = xml_events(
    "<!DOCTYPE x [<!ATTLIST x kind (1|two-three|a:b) '1'>]><x/>",
  )
  assert_true(
    events[0] is @xmlmini.Empty({ attributes, .. }) &&
    attributes.get("kind") == Some("1"),
  )
}

///|
test "maintenance XML PUBLIC identifier follows PubidChar without fetching" {
  assert_true(
    xml_error("<!DOCTYPE x PUBLIC 'bad\tidentifier' 'urn:ignored'><x/>"),
  )
  assert_true(xml_error("<!DOCTYPE x PUBLIC 'badé' 'urn:ignored'><x/>"))
  let events = xml_events(
    "<!DOCTYPE x PUBLIC '-//Example//DTD XML 1.0//EN' 'urn:ignored'><x/>",
  )
  assert_true(events[0] is @xmlmini.Empty({ name: "x", .. }))
}

///|
test "maintenance XML character references in entity values normalize in attribute context" {
  let events = xml_events(
    "<!DOCTYPE x [<!ENTITY spacing 'a&#9;b'><!ATTLIST x token NMTOKENS #IMPLIED>]><x direct='a&#9;b' indirect='&spacing;' token=' a&#9;b  c '>&spacing;</x>",
  )
  assert_true(
    events[0] is @xmlmini.Start({ attributes, .. }) &&
    attributes.get("direct") == Some("a\tb") &&
    attributes.get("indirect") == Some("a b") &&
    attributes.get("token") == Some("a\tb c"),
  )
  assert_true(events[1] is @xmlmini.Text("a\tb"))
}

///|
test "maintenance XML unused invalid character references are still malformed" {
  for value in ["&#0;", "&#xD800;", "&#x110000;", "&#;", "&bad", "100%"] {
    assert_true(
      xml_error("<!DOCTYPE x [<!ENTITY unused '" + value + "'>]><x/>"),
    )
  }
}

///|
test "maintenance XML checks internal ELEMENT and NOTATION declaration grammar" {
  for
    declaration in [
      "<!ELEMENT x nonsense>", "<!ELEMENT x ()>", "<!ELEMENT x (a|b,c)>", "<!ELEMENT x (#PCDATA|a)>",
      "<!ELEMENT x (a,,b)>", "<!NOTATION n nonsense>",
    ] {
    assert_true(xml_error("<!DOCTYPE x [" + declaration + "]><x/>"))
  }
  let events = xml_events(
    "<!DOCTYPE x [<!ELEMENT x ((a|b)+,c?)><!ELEMENT a EMPTY><!ELEMENT b ANY><!ELEMENT c (#PCDATA|a)*><!NOTATION image PUBLIC '-//Example//Notation'>]><x/>",
  )
  // Nonvalidating processing checks declaration syntax, not instance validity.
  assert_true(events[0] is @xmlmini.Empty({ name: "x", .. }))
}
