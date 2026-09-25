# Validation and testing

## Hardware validation: 0.2.x on macOS 27 / Apple silicon

- Native ARM64 application, encoder and dependencies.
- Installed LaunchAgent verified running, managed restart verified with a new PID,
  and both raster formats retested through installed binaries after restart.
- A second service instance is rejected; only one listener process remains.
- Two-page PWG Raster and square-resolution Apple Raster (AirPrint) jobs in color
  and monochrome; decoded HBPL page framing, media selection and color planes.
- Discovered and added via the actual macOS Add Printer dialog.
- TextEdit color document and two-page monochrome document printed via the normal
  Print dialog. User confirmed both look correct on 2026-09-24.
- Apple Raster at 1200 x 1200 is reduced vertically to the Dell's 1200 x 600 input
  using two-row averaging. Direct 1200 x 600 PWG Raster remains supported.

## Regression tests without paper

With a development service running and its capture queue configured:

```sh
clang -O2 tests/make-raster.c -lcups -o build/bin/make-raster
build/bin/make-raster build/two-page.pwg
build/bin/make-raster build/two-page.urf apple
touch build/capture.hbpl
build/bin/dell-printer add -u ipp://localhost:8631/ -d capture -m dell-c1765 -v "file://$PWD/build/capture.hbpl"
python3 tests/verify-capture.py
python3 tests/verify-capture.py build/two-page.urf
```

Add the capture queue only once. Each test checks color and monochrome jobs,
then decodes the saved Dell stream and verifies two pages and expected planes.
The capture queue is not migrated into the installed service.

## 0.3.0 repository and packaging checks

- Fresh dependency downloads passed all pinned SHA-256 checks.
- Built ARM64 executables from a clean source copy on macOS 27.
- Confirmed runtime linking uses only macOS system libraries/frameworks.
- Generated 48, 128, and 512 pixel AirPrint icons from bundled artwork.
- Checked shell syntax and rejection of an invalid installer address.
- Verified the release archive contains source archives, build instructions,
  project source, licenses, and artwork, with no spool, logs, or service state.
- Verified the release checksum and application version.

GitHub-hosted CI has not yet run. The 0.3.0 installer has not yet been exercised
through a complete hardware install/print cycle; prior hardware results above
are from 0.2.x. The printing implementation is unchanged apart from its version.

## Installer discovery

Run `python3 tests/test-discovery.py` for network-free discovery and selection
checks. These cover a single match, duplicate announcements, multiple printers,
no match, discovery errors, manual override, and invalid input. CI runs these.

For a live discovery check without installing or printing, run
`sh scripts/select-printer.sh`. A single physical C1765nfw was discovered over
Bonjour on macOS 27 without entering an address. The advertised hostname was
used rather than recording a machine-specific IP address in the repository.

## 0.3.1 background-service validation

- Built and packaged from a clean source tree with the included PAPPL patch.
- Verified the patch applies to pristine upstream sources and is safe to rerun.
- Installed on macOS 27; verified version 0.3.1 and no registered menu-bar app.
- Repeated color and monochrome two-page capture tests for both PWG and Apple
  Raster through the installed service, checking HBPL framing and color planes.
- Restarted the service and checked that the menu-bar app did not return.
- All 10 Bonjour discovery/selection tests pass. No physical pages were printed
  for this update.
