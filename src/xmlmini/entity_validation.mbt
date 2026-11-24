///|
fn predefined_entity(name : String) -> Bool {
  ["amp", "lt", "gt", "quot", "apos"].contains(name)
}

///|
// Scan the literal EntityValue, not its character-reference-expanded value.
// A character reference producing '&' must not invent a declaration dependency.
fn declared_references(
  raw : String,
  budget : XmlBudget,
) -> Array[String] raise XmlError {
  budget.charge_work(raw.length() + 1)
  let chars = raw.to_array()
  let result = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] != '&' {
      i += 1
      continue
    }
    i += 1
    let name = StringBuilder()
    while i < chars.length() && chars[i] != ';' {
      name.write_char(chars[i])
      i += 1
    }
    let value = name.to_string()
    if !value.has_prefix("#") && !predefined_entity(value) {
      result.push(value)
    }
    i += 1
  }
  result
}

///|
priv struct DependencyFrame {
  name : String
  children : Array[String]
  mut pos : Int
}

///|
fn validate_entity_declarations(
  entities : Map[String, DtdEntity],
  references : Map[String, Array[String]],
  all_references : Array[String],
  require_declared : Bool,
  budget : XmlBudget,
) -> Unit raise XmlError {
  for name in all_references {
    budget.charge_work(name.length() + 1)
    match entities.get(name) {
      None if require_declared =>
        raise Malformed("undeclared general entity in declaration")
      Some(Unparsed) =>
        raise Malformed("unparsed entity reference in entity declaration")
      _ => ()
    }
  }
  // Tri-colour graph traversal is iterative and visits each declaration/edge
  // once. It validates cycles without expanding a repeated dependency tree.
  let colours : Map[String, Int] = Map([])
  for (name, children) in references.to_array() {
    budget.charge_work(name.length() + 1)
    if colours.get(name) == Some(2) {
      continue
    }
    colours.set(name, 1)
    let stack = [{ name, children, pos: 0, }]
    while !stack.is_empty() {
      let frame : DependencyFrame = stack[stack.length() - 1]
      if frame.pos == frame.children.length() {
        colours.set(frame.name, 2)
        ignore(stack.pop())
        continue
      }
      let child = frame.children[frame.pos]
      frame.pos += 1
      budget.charge_work(child.length() + 1)
      match colours.get(child) {
        Some(1) => raise Malformed("recursive general entity")
        Some(2) => ()
        _ =>
          if references.get(child) is Some(next) {
            colours.set(child, 1)
            stack.push({ name: child, children: next, pos: 0, })
          }
      }
    }
  }
}
