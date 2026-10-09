#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
clang -O2 -arch arm64 -Wall -Wextra -Werror -Ivendor/pappl-1.4.10 -Ibuild/deps/include \
  -DDELL_VERSION=\"test\" tests/test-supplies.c \
  vendor/pappl-1.4.10/pappl/libpappl.a -Lbuild/deps/lib -lssl -lcrypto -lcups -lz -lpthread \
  -framework AppKit -framework CoreFoundation -framework SystemConfiguration \
  -o build/bin/test-supplies
build/bin/test-supplies
