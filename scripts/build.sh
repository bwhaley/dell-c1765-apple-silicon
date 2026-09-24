#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
root="$PWD"
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'Build on an Apple-silicon Mac with Xcode command-line tools.' >&2; exit 1
fi
version=$(cat VERSION)
xcrun --find clang >/dev/null
deps="$root/build/deps"
mkdir -p "$deps" build/bin
make -C vendor/foo2zjs-20200505dfsg0 foo2hbpl2 hbpldecode CC=clang CFLAGS='-O2 -arch arm64'
cp vendor/foo2zjs-20200505dfsg0/foo2hbpl2 build/bin/
for package in pkgconf-2.3.0 libressl-4.0.0; do
  (cd "vendor/$package"; ./configure --prefix="$deps" --disable-shared; make -j8; make install)
done
(cd vendor/pappl-1.4.10
 CPPFLAGS="-I$deps/include" LDFLAGS="-L$deps/lib" \
 PKG_CONFIG_PATH="$deps/lib/pkgconfig" PKGCONFIG="$deps/bin/pkgconf" CFLAGS='-O2 -arch arm64' \
 ./configure --prefix="$deps" --disable-shared --disable-libjpeg --disable-libpng --disable-libusb --disable-libpam
 make -j8)
clang -O2 -arch arm64 -Wall -Wextra -Ivendor/pappl-1.4.10 -I"$deps/include" \
  -DDELL_VERSION=\"$version\" src/dell-printer.c \
  vendor/pappl-1.4.10/pappl/libpappl.a -L"$deps/lib" -lssl -lcrypto -lcups -lz -lpthread \
  -framework AppKit -framework CoreFoundation -framework SystemConfiguration -o build/bin/dell-printer
file build/bin/dell-printer build/bin/foo2hbpl2

sh scripts/prepare-icons.sh build/icons
