#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
shasum -a 256 -c scripts/sources.sha256
tar -xf vendor/foo2zjs.tar.xz -C vendor
tar -xf vendor/pappl.tar.gz -C vendor
tar -xf vendor/libressl.tar.gz -C vendor
tar -xf vendor/pkgconf.tar.xz -C vendor
