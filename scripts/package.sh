#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
version=$(cat VERSION)
case "$version" in *[!0-9.]*|'') echo 'Invalid VERSION' >&2; exit 1;; esac
mkdir -p dist
# A fresh staging directory prevents old build files leaking into releases.
work=$(mktemp -d "$PWD/dist/package.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
stage="$work/DellNative-$version"
mkdir -p "$stage/payload/bin" "$stage/Notices" "$stage/Source/vendor"
cp build/bin/dell-printer build/bin/foo2hbpl2 "$stage/payload/bin/"
cp scripts/Install.command scripts/Uninstall.command scripts/prepare-icons.sh \
  scripts/discover-printers.sh scripts/select-printer.sh "$stage/"
chmod 755 "$stage/Install.command" "$stage/Uninstall.command" "$stage/payload/bin/"*
cp vendor/foo2zjs-20200505dfsg0/COPYING "$stage/Notices/foo2zjs-COPYING.txt"
cp vendor/pappl-1.4.10/LICENSE "$stage/Notices/PAPPL-LICENSE.txt"
cp vendor/pappl-1.4.10/NOTICE "$stage/Notices/PAPPL-NOTICE.txt"
cp vendor/libressl-4.0.0/COPYING "$stage/Notices/LibreSSL-COPYING.txt"
cp vendor/pkgconf-2.3.0/COPYING "$stage/Notices/pkgconf-COPYING.txt"
cp README.md LICENSE THIRD_PARTY_NOTICES.md VERSION CHANGELOG.md CONTRIBUTING.md "$stage/"
ditto assets "$stage/assets"
for directory in src scripts tests docs assets; do ditto "$directory" "$stage/Source/$directory"; done
cp README.md LICENSE THIRD_PARTY_NOTICES.md VERSION CHANGELOG.md CONTRIBUTING.md .gitignore "$stage/Source/"
cp vendor/foo2zjs.tar.xz vendor/pappl.tar.gz vendor/libressl.tar.gz vendor/pkgconf.tar.xz "$stage/Source/vendor/"
printf '%s\n' 'Run sh scripts/unpack-sources.sh, then sh scripts/build.sh (Apple silicon and Xcode tools required).' > "$stage/Source/BUILD.txt"
codesign --verify --strict "$stage/payload/bin/dell-printer"
codesign --verify --strict "$stage/payload/bin/foo2hbpl2"
archive="$PWD/dist/DellNative-$version.zip"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr -c -k --keepParent "$stage" "$archive"
(cd dist; shasum -a 256 "DellNative-$version.zip" > "DellNative-$version.zip.sha256")
echo "$archive"
