# Architecture

The root package exposes the public parsing entry point. `src/model` owns the
format-independent data model; `src/jsonfeed` decodes and normalizes JSON Feed.

Reserved boundaries for later phases: `src/detect`, `src/rss`, `src/atom`, and
`src/datetime`. They have no implementation in phase one. `cli` is reserved for a
future command-line application. Executable library usage belongs in `examples`.
Fixtures are grouped by format under `fixtures`. Empty reserved directories are
not tracked in Git; samples and packages will be added with their implementations.
