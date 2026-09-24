# Preparing a release

1. Update VERSION and CHANGELOG.md together. Build from a clean checkout using
   the README instructions, then run relevant capture and installation checks.
2. Inspect the package contents. Confirm it includes Source/, its four upstream
   archives, build scripts, VERSION, assets, LICENSE, and all Notices. It must not
   contain print jobs, service state, logs, machine paths, or credentials.
3. Commit reviewed changes and tag the release as `v<VERSION>`.
4. Create a GitHub Release and upload `dist/DellNative-<VERSION>.zip` and its
   `.zip.sha256` file. Publish the complete ZIP, including Source/, rather than
   distributing the binaries alone. Describe tested macOS/hardware combinations
   and the ad-hoc signing status.

CI builds and packages on an Apple-silicon macOS runner and uploads a temporary
build artifact. It does not create tags, publish releases, install a service, or
print documents. Hardware verification remains a manual release check.

The workflow uses the standard macOS 15 ARM64 runner described in
[GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
