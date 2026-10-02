///|
fn datetime_error(input : String) -> @datetime.DateTimeError raise {
  @test.expect_error(() => @datetime.parse_datetime(input))
}

///|
fn timestamp(input : String) -> Int64 raise @datetime.DateTimeError {
  @datetime.parse_datetime(input).unix_seconds
}

///|
test "RFC3339 UTC, numeric offsets, and fractional seconds" {
  let z = @datetime.parse_rfc3339("2026-10-03T12:00:00Z")
  let plus = @datetime.parse_rfc3339("2026-10-03T20:00:00+08:00")
  let minus = @datetime.parse_rfc3339("2026-10-03T07:00:00-05:00")
  let half_hour = @datetime.parse_rfc3339("2026-10-03T06:30:00-05:30")
  let fraction = @datetime.parse_rfc3339("2026-10-03T12:00:00.123Z")
  @test.assert_eq(z.unix_seconds, plus.unix_seconds)
  @test.assert_eq(z.unix_seconds, minus.unix_seconds)
  @test.assert_eq(z.unix_seconds, half_hour.unix_seconds)
  @test.assert_eq(z.unix_seconds, fraction.unix_seconds)
  @test.assert_eq(fraction.raw, "2026-10-03T12:00:00.123Z")
  @test.assert_eq(z.compare(plus), 0)
}

///|
test "RFC3339 leap years and invalid calendar fields" {
  assert_true(@datetime.parse_rfc3339("2024-02-29T12:00:00Z").unix_seconds > 0L)
  assert_true(
    datetime_error("2026-02-30T12:00:00Z")
    is @datetime.DateTimeError::InvalidDay,
  )
  assert_true(
    datetime_error("2026-13-01T12:00:00Z")
    is @datetime.DateTimeError::InvalidMonth,
  )
  assert_true(
    datetime_error("2026-00-01T12:00:00Z")
    is @datetime.DateTimeError::InvalidMonth,
  )
  assert_true(
    datetime_error("2026-04-31T12:00:00Z")
    is @datetime.DateTimeError::InvalidDay,
  )
  assert_true(
    datetime_error("2023-02-29T12:00:00Z")
    is @datetime.DateTimeError::InvalidDay,
  )
}

///|
test "RFC3339 validates clock and timezone offset" {
  assert_true(
    datetime_error("2026-10-03T24:00:00Z")
    is @datetime.DateTimeError::InvalidTime,
  )
  assert_true(
    datetime_error("2026-10-03T12:60:00Z")
    is @datetime.DateTimeError::InvalidTime,
  )
  assert_true(
    datetime_error("2026-10-03T12:00:60Z")
    is @datetime.DateTimeError::InvalidTime,
  )
  assert_true(
    datetime_error("2026-10-03T12:00:00+24:00")
    is @datetime.DateTimeError::InvalidOffset,
  )
  assert_true(
    datetime_error("2026-10-03T12:00:00+08:60")
    is @datetime.DateTimeError::InvalidOffset,
  )
  assert_true(
    datetime_error("2026-10-03T12:00:00")
    is @datetime.DateTimeError::InvalidFormat,
  )
  assert_true(
    datetime_error("2026-10-03T12:00:00.Z")
    is @datetime.DateTimeError::InvalidTime,
  )
}

///|
test "RSS dates support weekdays optional weekdays and known zones" {
  let gmt = @datetime.parse_rss_datetime("Wed, 02 Oct 2002 13:00:00 GMT")
  let numeric = @datetime.parse_rss_datetime("02 Oct 2002 13:00:00 +0000")
  let utc = @datetime.parse_rss_datetime("Wed, 02 Oct 2002 13:00:00 UTC")
  @test.assert_eq(gmt.unix_seconds, 1033563600L)
  @test.assert_eq(gmt.unix_seconds, numeric.unix_seconds)
  @test.assert_eq(gmt.unix_seconds, utc.unix_seconds)
  @test.assert_eq(
    @datetime.parse_rss_datetime("Mon, 3 Jun 2008 11:05:30 GMT").raw,
    "Mon, 3 Jun 2008 11:05:30 GMT",
  )
  @test.assert_eq(
    @datetime.parse_rss_datetime("2 Oct 2002 13:00 GMT").unix_seconds,
    1033563600L,
  )
  @test.assert_eq(
    @datetime.parse_rss_datetime("Tue, 3 Jun 2008 11:05:30 GMT").raw,
    "Tue, 3 Jun 2008 11:05:30 GMT",
  )
}

///|
test "RSS dates support positive and negative numeric offsets" {
  let z = @datetime.parse_rss_datetime("03 Oct 2026 12:00:00 +0000")
  let plus = @datetime.parse_rss_datetime("03 Oct 2026 20:00:00 +0800")
  let colon_plus = @datetime.parse_rss_datetime("03 Oct 2026 20:00:00 +08:00")
  let minus = @datetime.parse_rss_datetime("03 Oct 2026 07:00:00 -0500")
  let rfc = @datetime.parse_rfc3339("2026-10-03T12:00:00Z")
  @test.assert_eq(z.unix_seconds, plus.unix_seconds)
  @test.assert_eq(z.unix_seconds, colon_plus.unix_seconds)
  @test.assert_eq(z.unix_seconds, minus.unix_seconds)
  @test.assert_eq(z.unix_seconds, rfc.unix_seconds)
}

///|
test "RSS date parser accepts all English month abbreviations" {
  let months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  for month in months {
    let date = "1 " + month + " 2024 00:00:00 GMT"
    assert_true(@datetime.parse_rss_datetime(date).unix_seconds > 0L)
  }
}

///|
test "RSS date parser rejects invalid month format and ambiguous zones" {
  assert_true(
    datetime_error("1 Xxx 2024 00:00:00 GMT")
    is @datetime.DateTimeError::InvalidMonth,
  )
  assert_true(
    datetime_error("1 January 2024 00:00:00 GMT")
    is @datetime.DateTimeError::InvalidMonth,
  )
  assert_true(
    datetime_error("Wed, 02 Oct 2002 13:00:00 EST")
    is @datetime.DateTimeError::UnsupportedTimezone(_),
  )
  assert_true(
    datetime_error("02 Oct 2002 13:00:00 PST")
    is @datetime.DateTimeError::UnsupportedTimezone(_),
  )
  assert_true(
    datetime_error("garbage") is @datetime.DateTimeError::InvalidFormat,
  )
}

///|
test "RSS and RFC3339 equivalents normalize to the same instant" {
  let rfc = @datetime.parse_datetime("2002-10-02T13:00:00Z")
  let rss_gmt = @datetime.parse_datetime("Wed, 02 Oct 2002 13:00:00 GMT")
  let rss_offset = @datetime.parse_datetime("Wed, 02 Oct 2002 15:00:00 +0200")
  @test.assert_eq(rfc.unix_seconds, rss_gmt.unix_seconds)
  @test.assert_eq(rss_gmt.unix_seconds, rss_offset.unix_seconds)
  @test.assert_eq(timestamp("2002-10-02T13:00:00Z"), 1033563600L)
}
