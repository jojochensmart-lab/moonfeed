///|
/// Atom's RFC 3339 semantics, retaining precision and leap-second identity.
fn atom_date(value : String, path : String) -> AtomDate raise ParseError {
  let a = value.to_array()
  let leap_second = a.length() >= 19 && a[17] == '6' && a[18] == '0'
  let year_zero = value.has_prefix("0000-")
  let adjusted = a.copy()
  if leap_second {
    adjusted[17] = '5'
    adjusted[18] = '9'
  }
  // 2000 and 0000 have identical calendars separated by five Gregorian cycles.
  if year_zero {
    adjusted[0] = '2'
  }
  let parsed = @datetime.parse_rfc3339(
    chars_span(adjusted, 0, adjusted.length()),
  ) catch {
    e => raise InvalidDateTime(path, e)
  }
  let seconds = parsed.unix_seconds -
    (if year_zero { 63113904000L } else { 0L }) +
    (if leap_second { 1L } else { 0L })
  if leap_second {
    // Public-domain IANA/IERS transitions through 2017-01-01. The current
    // announcement audit is recorded in docs/LEAP_SECONDS.md; no runtime download.
    // https://data.iana.org/time-zones/tzdb/leap-seconds.list
    let transitions = [
      2287785600L, 2303683200L, 2335219200L, 2366755200L, 2398291200L, 2429913600L,
      2461449600L, 2492985600L, 2524521600L, 2571782400L, 2603318400L, 2634854400L,
      2698012800L, 2776982400L, 2840140800L, 2871676800L, 2918937600L, 2950473600L,
      2982009600L, 3029443200L, 3076704000L, 3124137600L, 3345062400L, 3439756800L,
      3550089600L, 3644697600L, 3692217600L,
    ]
    if !transitions.any(t => t == seconds + 2208988800L) {
      raise InvalidRequiredField(
        path, "date is not a recorded positive leap second",
      )
    }
  }
  let fractional_digits = if a.length() > 19 && a[19] == '.' {
    let mut end = 20
    while end < a.length() && ascii_digit(a[end]) {
      end += 1
    }
    Some(chars_span(a, 20, end))
  } else {
    None
  }
  {
    raw: value,
    unix_seconds: seconds,
    fractional_digits,
    leap_second,
    unknown_local_offset: value.has_suffix("-00:00"),
  }
}
