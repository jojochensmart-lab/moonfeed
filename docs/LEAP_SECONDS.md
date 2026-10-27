# Leap-second data maintenance

Atom dates preserve the original value, fractional digits, UTC Unix seconds, the `-00:00` convention, and whether the timestamp uses a leap second. The positive leap-second transition table is embedded in `src/atom/date.mbt`; parsing is offline and never downloads time data.

## Current verification

Checked on 2026-10-27 against the IERS Bulletin C archive. Bulletin C 72, dated 2026-07-06, states that no leap second will be introduced at the end of December 2026 and that UTC−TAI has remained −37 seconds since 2017-01-01. Bulletin C 71 states that no leap second was introduced at the end of June 2026. The embedded transition table therefore remains current through the latest announced transition, 2016-12-31 (effective 2017-01-01).

Sources: [IERS Bulletin C archive](https://datacenter.iers.org/availableVersions.php?id=16), [Bulletin C 72](https://datacenter.iers.org/data/html/bulletinc-072.html), [IANA tzdb leap-seconds.list](https://data.iana.org/time-zones/tzdb/leap-seconds.list).

## Update procedure

Review the IERS Bulletin C archive whenever a new issue is published; IERS issues a bulletin every six months, either announcing a time step or confirming no step at the next possible date.

When a new positive leap second is announced:

1. Verify the effective UTC date in the official bulletin and cross-check the IANA tzdb list.
2. Add the corresponding UTC transition value to `src/atom/date.mbt`. Keep the table in chronological order and preserve the source attribution.
3. Add Atom date tests for the announced leap second in UTC and with a non-zero offset representing the same instant; assert the retained `leap_second` flag, raw value, and normalized seconds.
4. Keep a negative vector for an unannounced candidate date. Run the default and JS test targets, check, and build.
5. Update this record, the RFC 4287 matrix, and the changelog with the bulletin number and verification date.

If a bulletin announces no change, record that check and leave the embedded transition table unchanged. Never infer or accept a future leap second from a calendar pattern. No negative leap second has been announced; adding support for one would require an explicit format and normalization design review.
