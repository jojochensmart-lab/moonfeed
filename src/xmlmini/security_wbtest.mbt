///|
fn security_decode(
  value : String,
  entities : Map[String, DtdEntity],
  limits : XmlLimits,
) -> String raise XmlError {
  decode_xml_value(value, entities, new_budget(limits))
}

///|
test "security empty expansion pays reference budget with exact inclusive boundary" {
  let entities : Map[String, DtdEntity] = Map([("e", Internal(""))])
  let limits = { ..xml_limits(), references: 2, }
  assert_eq(security_decode("&e;&e;", entities, limits), "")
  for _ in 0..<3 {
    assert_true(
      @test.expect_error(() => security_decode("&e;&e;&e;", entities, limits))
      is Malformed("XML entity reference limit exceeded"),
    )
  }
}

///|
test "security empty nested expansion pays work before output exists" {
  let entities : Map[String, DtdEntity] = Map([
    ("a", Internal("&e;&e;")),
    ("e", Internal("")),
  ])
  // Root frame costs 4, a costs 7, and two empty frames cost 1 each.
  assert_eq(security_decode("&a;", entities, { ..xml_limits(), work: 13, }), "")
  assert_true(
    @test.expect_error(() => {
      security_decode("&a;", entities, { ..xml_limits(), work: 12, })
    })
    is Malformed("XML expansion work limit exceeded"),
  )
}

///|
test "security exponential empty expansion stops at small work budget" {
  let entities : Map[String, DtdEntity] = Map([("e0", Internal(""))])
  for i = 1; i <= 20; i = i + 1 {
    let reference = "&e" + (i - 1).to_string() + ";"
    entities.set("e" + i.to_string(), Internal(reference + reference))
  }
  assert_true(
    @test.expect_error(() => {
      security_decode("&e20;", entities, { ..xml_limits(), work: 128, })
    })
    is Malformed("XML expansion work limit exceeded"),
  )
}

///|
test "security depth is bounded without host recursion" {
  let entities : Map[String, DtdEntity] = Map([("e0", Internal("x"))])
  for i = 1; i <= 32; i = i + 1 {
    entities.set(
      "e" + i.to_string(),
      Internal("&e" + (i - 1).to_string() + ";"),
    )
  }
  assert_eq(security_decode("&e31;", entities, xml_limits()), "x")
  assert_true(
    @test.expect_error(() => security_decode("&e32;", entities, xml_limits()))
    is Malformed("general entity nesting limit exceeded"),
  )
}

///|
test "security cycles report errors instead of unbounded recursion" {
  for
    entities in [
      Map([("e", Internal("&e;"))]),
      Map([("e", Internal("&f;")), ("f", Internal("&e;"))]),
    ] {
    assert_true(
      @test.expect_error(() => security_decode("&e;", entities, xml_limits()))
      is Malformed("recursive general entity"),
    )
  }
}

///|
test "security output budget counts UTF8 bytes and exact boundary" {
  let entities : Map[String, DtdEntity] = Map([("e", Internal("月🌙"))])
  assert_eq(
    security_decode("&e;", entities, { ..xml_limits(), output_bytes: 7, }),
    "月🌙",
  )
  assert_true(
    @test.expect_error(() => {
      security_decode("&e;", entities, { ..xml_limits(), output_bytes: 6, })
    })
    is Malformed("XML output byte limit exceeded"),
  )
}

///|
test "security budgets survive value node and attribute boundaries" {
  let reader = reader_with_limits("<x a='&amp;'>&amp;<![CDATA[z]]></x>", {
    ..xml_limits(),
    references: 1,
  })
  assert_true(
    reader.read_event() is Start({ attributes, .. }) &&
    attributes.get("a") == Some("&"),
  )
  assert_true(
    @test.expect_error(() => reader.read_event())
    is Malformed("XML entity reference limit exceeded"),
  )
  // Resource failures are sticky: a caller cannot resume after exhausting one.
  assert_true(
    @test.expect_error(() => reader.read_event())
    is Malformed("XML entity reference limit exceeded"),
  )
  let output = reader_with_limits("<x a='月'><![CDATA[🌙]]></x>", {
    ..xml_limits(),
    output_bytes: 6,
  })
  assert_true(output.read_event() is Start(_))
  assert_true(
    @test.expect_error(() => output.read_event())
    is Malformed("XML output byte limit exceeded"),
  )
}

///|
test "security document budgets include DTD default validation and reuse" {
  let reader = reader_with_limits(
    "<!DOCTYPE x [<!ENTITY e ''><!ATTLIST x a CDATA '&e;'>]><x/>",
    { ..xml_limits(), references: 1, },
  )
  assert_true(
    @test.expect_error(() => reader.read_event())
    is Malformed("XML entity reference limit exceeded"),
  )
  let declared = reader_with_limits(
    "<!DOCTYPE x [<!ENTITY unused '&#65;&#66;'>]><x/>",
    { ..xml_limits(), references: 1, },
  )
  assert_true(
    @test.expect_error(() => declared.read_event())
    is Malformed("XML entity reference limit exceeded"),
  )
}

///|
test "security input and element depth limits fail deterministically" {
  let exact = reader_with_limits("<x/>", { ..xml_limits(), input_bytes: 4, })
  assert_true(exact.read_event() is Empty(_))
  let bom = reader_with_limits("\u{FEFF}<x/>", {
    ..xml_limits(),
    input_bytes: 7,
  })
  assert_true(bom.read_event() is Empty(_))
  let lines = reader_with_limits("\r\n<x/>", { ..xml_limits(), input_bytes: 6, })
  assert_true(lines.read_event() is Text("\n"))
  assert_true(lines.read_event() is Empty(_))
  let unicode_exact = reader_with_limits("<x>月</x>", {
    ..xml_limits(),
    input_bytes: 10,
  })
  assert_true(unicode_exact.read_event() is Start(_))
  assert_true(unicode_exact.read_event() is Text("月"))
  let too_big = reader_with_limits("<x/> ", { ..xml_limits(), input_bytes: 4, })
  assert_true(
    @test.expect_error(() => too_big.read_event())
    is Malformed("XML input byte limit exceeded"),
  )
  let unicode = reader_with_limits("<x>月</x>", {
    ..xml_limits(),
    input_bytes: 9,
  })
  assert_true(
    @test.expect_error(() => unicode.read_event())
    is Malformed("XML input byte limit exceeded"),
  )
  let nested = reader_with_limits("<x><x><x></x></x></x>", {
    ..xml_limits(),
    element_depth: 2,
  })
  assert_true(nested.read_event() is Start(_))
  assert_true(nested.read_event() is Start(_))
  assert_true(
    @test.expect_error(() => nested.read_event())
    is Malformed("XML element nesting limit exceeded"),
  )
}

///|
test "security entity and external policies retain explicit diagnostics" {
  assert_true(
    @test.expect_error(() => security_decode("&missing;", Map([]), xml_limits()))
    is Malformed("undeclared general entity"),
  )
  assert_true(
    @test.expect_error(() => {
      security_decode("&e;", Map([("e", External)]), xml_limits())
    })
    is Malformed("external general entity expansion is unsupported"),
  )
  assert_true(
    @test.expect_error(() => {
      security_decode("&e;", Map([("e", Internal("<b/>"))]), xml_limits())
    })
    is Malformed("markup in a general entity is unsupported"),
  )
}
