# Preparing a release

1. Update VERSION and CHANGELOG.md together. Build from a clean checkout using
   the README instructions, then run relevant capture and installation checks.
2. Inspect the package contents. Confirm it includes Source/, its four upstream
   archives, build scripts, VERSION, assets, LICENSE, and all Notices. It must not
   contain print jobs, service state, logs, machine paths, or credentials.
3. Add release notes at `docs/releases/<VERSION>.md`, commit reviewed changes,
   and push the commit and an annotated `v<VERSION>` tag.
4. The tag triggers a fresh macOS build. After it succeeds, GitHub Actions
   publishes a release with the complete ZIP and checksum. Verify the release
   assets and workflow result before announcing it.

Branch and pull-request builds upload temporary build artifacts only. The release
job has write permission only for version-tag pushes. CI does not install a
service or print documents. Hardware verification remains a manual release check.

The workflow uses the standard macOS 15 ARM64 runner described in
[GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
