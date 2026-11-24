///|
test "declarations reject parameter NDATA and missing NDATA separator" {
  for definition in ["SYSTEM 'urn:p' NDATA n", "PUBLIC 'id' 'urn:p' NDATA n"] {
    assert_true(
      @test.expect_error(() => {
        xml_events("<!DOCTYPE x [<!ENTITY % p " + definition + ">]><x/>")
      })
      is @xmlmini.Malformed("NDATA is forbidden for parameter entities"),
    )
  }
  assert_true(xml_error("<!DOCTYPE x [<!ENTITY e SYSTEM 'urn:e'NDATA n>]><x/>"))
}

///|
test "declarations require prior direct and indirect default entity declarations" {
  for
    subset in [
      "<!ATTLIST absent a CDATA '&missing;'>", "<!ATTLIST x a CDATA '&later;'><!ENTITY later 'v'>",
      "<!ENTITY outer '&later;'><!ATTLIST absent a CDATA '&outer;'><!ENTITY later 'v'>",
    ] {
    assert_true(
      @test.expect_error(() => xml_events("<!DOCTYPE x [" + subset + "]><x/>"))
      is @xmlmini.Malformed("undeclared general entity"),
    )
  }
}

///|
test "declarations retain legal forward general references and prior defaults" {
  let events = xml_events(
    "<!DOCTYPE x [<!ENTITY outer '&later;'><!ENTITY later 'v'><!ENTITY later 'ignored'><!ATTLIST x a CDATA '&outer;'>]><x>&outer;</x>",
  )
  assert_true(
    events[0] is @xmlmini.Start({ attributes, .. }) &&
    attributes.get("a") == Some("v"),
  )
  assert_true(events[1] is @xmlmini.Text("v"))
}

///|
test "declarations check unused dependencies without expanding them" {
  assert_true(
    @test.expect_error(() => {
      xml_events("<!DOCTYPE x [<!ENTITY e '&missing;'>]><x/>")
    })
    is @xmlmini.Malformed("undeclared general entity in declaration"),
  )
  for subset in ["<!ENTITY e '&e;'>", "<!ENTITY a '&b;'><!ENTITY b '&a;'>"] {
    assert_true(
      @test.expect_error(() => xml_events("<!DOCTYPE x [" + subset + "]><x/>"))
      is @xmlmini.Malformed("recursive general entity"),
    )
  }
  // A nonvalidating reader cannot assume an unread external subset declares nothing.
  assert_true(
    xml_events("<!DOCTYPE x SYSTEM 'urn:unread' [<!ENTITY e '&unknown;'>]><x/>")[0]
    is @xmlmini.Empty(_),
  )
  assert_true(
    @test.expect_error(() => {
      xml_events(
        "<?xml version='1.0' standalone='yes'?><!DOCTYPE x SYSTEM 'urn:unread' [<!ENTITY e '&unknown;'>]><x/>",
      )
    })
    is @xmlmini.Malformed("undeclared general entity in declaration"),
  )
}

///|
test "declarations distinguish forbidden parameter positions from unsupported use" {
  assert_true(
    @test.expect_error(() => {
      xml_events("<!DOCTYPE x [<!ENTITY % p 'v'><!ENTITY e '%p;'>]><x/>")
    })
    is @xmlmini.Malformed(
      "parameter entity reference inside internal declaration is forbidden"
    ),
  )
  assert_true(
    @test.expect_error(() => {
      xml_events("<!DOCTYPE x [<!ENTITY % p 'v'>%p;]><x/>")
    })
    is @xmlmini.Malformed("parameter entity references are unsupported"),
  )
  assert_true(xml_error("%p;<x/>"))
  assert_true(xml_error("<x/>%p;"))
}

///|
test "declarations distinguish forbidden unparsed references and disabled external access" {
  assert_true(
    @test.expect_error(() => {
      xml_events(
        "<!DOCTYPE x [<!ENTITY e SYSTEM 'file:///never-read'>]><x>&e;</x>",
      )
    })
    is @xmlmini.Malformed("external general entity expansion is unsupported"),
  )
  assert_true(
    @test.expect_error(() => {
      xml_events("<!DOCTYPE x [<!ENTITY e SYSTEM 'urn:e' NDATA n>]><x>&e;</x>")
    })
    is @xmlmini.Malformed("unparsed entity reference is forbidden"),
  )
  assert_true(
    @test.expect_error(() => {
      xml_events(
        "<!DOCTYPE x [<!ENTITY e SYSTEM 'urn:e' NDATA n><!ENTITY a '&e;'>]><x/>",
      )
    })
    is @xmlmini.Malformed("unparsed entity reference in entity declaration"),
  )
  assert_true(
    @test.expect_error(() => {
      xml_events("<!DOCTYPE x [<!ENTITY e '<b/>'>]><x a='&e;'/ >")
    })
    is @xmlmini.Malformed("less-than sign in attribute entity replacement"),
  )
}
