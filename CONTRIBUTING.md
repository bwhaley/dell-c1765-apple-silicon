# Contributing

Build using the README instructions. Keep changes focused, explain the observed
problem and resulting behavior, and describe validation in the pull request.
Use shell syntax checks for script changes and the capture tests in docs/TESTING.md
for raster/encoder changes. Do not send jobs to a physical printer without its
owner's consent. State clearly when a change has not been tested on hardware.

Do not commit spool files, documents, logs, local printer addresses, generated
binaries, extracted dependencies, or credentials. Use reserved example addresses
or placeholders in documentation. Preserve third-party notices and artwork
attribution. Original-code contributions use the project's MIT terms.

For a dependency update, update both scripts/sources.urls and
scripts/sources.sha256, build from a fresh checkout, and repeat relevant tests.
