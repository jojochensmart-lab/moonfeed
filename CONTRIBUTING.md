# Contributing to MoonFeed

Thanks for helping improve MoonFeed. The project implements JSON Feed 1.1, RSS 2.0, and Atom 1.0 support for MoonBit. Atom support is still being brought toward full RFC 4287 conformance; check the [compatibility matrix](docs/ATOM_RFC4287_COMPLIANCE.md) before describing its coverage.

## Requirements

- MoonBit v0.10.14 or newer. Local development is verified with v0.10.14; GitHub Actions records and tests the installed toolchain version.
- Node.js for the JavaScript target tests and the repository CLI smoke tests.

## Set up and verify

From the repository root, run:

```sh
moon info
moon fmt
moon fmt --check
moon check
moon test
moon build
moon test --target js
moon build --target js
moon tree
moon run examples/basic
moon run examples/atom
```

The CLI is a MoonBit program run on Node.js. Its current smoke commands are listed in [README.md](README.md). When changing public APIs, update the examples and the relevant `.mbti` interface, then inspect the interface diff.

## Tests and behavior changes

Add regression tests beside the parser or API they exercise. Use the existing fixtures when they represent the behavior clearly; keep new fixtures small and include their source and license when derived from an external work. Assert parsed values, errors, and paths instead of only checking that parsing succeeds. Run the focused test while developing, then run the full verification commands above before opening a pull request.

Keep the format boundaries clear:

- JSON Feed, RSS, and Atom normalization should preserve the behavior of existing callers.
- Use the Atom document API when strict Atom document validation or Atom-specific metadata is required; the older `parse_atom` and unified `parse` APIs retain their compatibility behavior. See [API compatibility](docs/API_COMPATIBILITY.md).
- The internal XML reader implements the subset required by feed parsing, not a general-purpose XML library.
- Do not describe Atom as fully RFC 4287 compatible while the compliance matrix still contains `PARTIAL` entries.

## Pull requests and licensing

Describe the user-visible change, the format or API it affects, and the commands used to verify it. Include a small input example for parser changes when that makes the behavior easier to review. Keep unrelated application or submission materials out of source changes.

MoonFeed is distributed under [Apache License 2.0](LICENSE). Contributions are submitted for inclusion under that license. Do not copy third-party code, documentation, or feed fixtures without confirming that their license permits redistribution and recording the source where appropriate.
