# Dell C1765nfw Native

Print to a Dell C1765nfw from an Apple-silicon Mac without running Intel printer
software. A native PAPPL application accepts AirPrint jobs from macOS and sends
HBPL data to the printer over the network using foo2hbpl2.

Supports color, monochrome, and multipage printing on Letter/A4 plain paper.
This is an experimental, independent project, not an official Dell driver.

## Potential compatibility with other printers

Only the Dell C1765nfw has been tested with this project. Other printers supported
by the same `foo2hbpl2` encoder may be candidates for support, including:

- Dell 1355
- Fuji Xerox DocuPrint CM205 and CM215
- Xerox WorkCentre 6015
- Epson AcuLaser CX17NF

See [OpenPrinting's full foo2hbpl2 compatibility list](https://openprinting.org/driver/foo2hbpl2/).
That list describes the upstream encoder's support, not verified compatibility
with this macOS application. These models are **untested here** and may need
changes to resolution, color handling, or other device settings.

Automatic discovery currently selects only the C1765nfw. Testing another model
requires a manual hostname/IP address and network printing on TCP port 9100;
USB printing is not supported. Scanning and fax are outside this project's scope.

## Install

1. Download and unzip the installer ZIP from this repository's GitHub Releases,
   when a release is available.
2. Open `Install.command`. It finds your C1765nfw automatically using Bonjour.
   If several are found, choose one from the list. Keep the Mac and printer on
   the same network and enable Bonjour on the printer.
3. Select **Dell C1765nfw Native** in the normal macOS Print dialog.

Discovery uses the printer's `.local` hostname so changes to its IP address
should not require reinstalling. If discovery finds no supported printer, the
installer offers manual address entry or cancellation. On networks that block
Bonjour, you can also run `sh Install.command PRINTER_IP_OR_HOSTNAME` in the
extracted installer folder. The installer includes the Dell artwork; the old Dell driver
is not required. Reopen Print Center if its icon display needs refreshing.

Requires an Apple-silicon Mac and a network-connected C1765nfw reachable on TCP
port 9100. Tested on macOS 27. Earlier macOS versions and macOS 28 are unverified.
Packages are ad-hoc signed, not Developer ID signed or notarized; macOS may block
opening a downloaded installer. Review the source and macOS's displayed details
before choosing whether to allow it. Installation needs permission to manage the
local print queue. No Homebrew or Xcode is needed to run a prebuilt package.

## How it runs

The installer copies the service into `~/Library/Application Support/DellNative`
and registers `~/Library/LaunchAgents/local.dell-native.printer.plist`. It starts
at login and restarts if it exits. Keep that account logged in to print.
Moving or deleting the source checkout does not affect the installed service.

The service listens on localhost:8631 and forwards jobs to the printer's port
9100. macOS rasterizes documents using its native AirPrint support. The installer
uses macOS's `ipp2ppd` utility to configure the queue and register its icon.
Only one service instance can run per user.

Run the installed `Uninstall.command` (or the one in the package) to remove the
native queue and service and move installed files to Trash. Other printer queues
and the legacy Dell driver are left alone. macOS may retain cached printer icons.

## Build from source

On an Apple-silicon Mac with Xcode command-line tools (`xcode-select --install`):

```sh
sh scripts/fetch-sources.sh
sh scripts/unpack-sources.sh
sh scripts/build.sh
sh scripts/package.sh
```

Downloads are pinned and verified against SHA-256 checksums. No Homebrew is used.
The resulting `dist/DellNative-<version>.zip` includes executables, artwork,
licenses, and corresponding source archives and build instructions. A checksum
file is generated alongside it. VERSION is the shared application/package version.
Build artifacts and downloaded dependencies are deliberately excluded from Git.
Do not reuse generated build/vendor trees after moving a checkout; start from a
fresh clone or re-extract dependencies and rebuild with the new path.

For development, `sh scripts/run.sh` starts a foreground service. Stop the
installed service before using it. See [testing](docs/TESTING.md),
[contributing](CONTRIBUTING.md), and [releasing](docs/RELEASING.md).

## Limits

One-sided plain paper only; one paper size per job; at most 100 pages per job.
Basic RGB-to-CMYK conversion and ordered dithering, without calibrated profiles.
No scanning, fax, duplex, USB, or toner-level monitoring. Cancellation is checked
before output and between output chunks, not during encoding. Copies, A4 physical
output, and extensive failure recovery are not yet validated. See the testing
record for what has actually been checked.

## License and attribution

Original code is MIT; see [LICENSE](LICENSE).
[Third-party notices](THIRD_PARTY_NOTICES.md) cover dependencies.
[Dell artwork](assets/README.md) is separately attributed and is not covered by the MIT license.
