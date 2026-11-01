#!/usr/bin/env bash
# Smoke-test one image on the machine's own architecture:
#   ./test.sh <image> <tcl-version>        ENGINE=podman ./test.sh ...
#   PLATFORM=linux/amd64 ./test.sh ...     test another architecture under emulation
# Checks version, CPU, threads, and that bundled packages and zlib load (8.6+).
# tclsh is set as the entrypoint so the same test also runs on the shell-less distroless variant.
set -euo pipefail
image=$1 version=$2
engine=${ENGINE:-docker}
case "${PLATFORM:-$(uname -m)}" in
	linux/amd64 | x86_64) platform=linux/amd64 machine=x86_64 ;;
	linux/arm64 | arm64 | aarch64) platform=linux/arm64 machine=aarch64 ;;
	*) echo "unsupported platform: ${PLATFORM:-$(uname -m)}" >&2; exit 1 ;;
esac

"$engine" run --rm -i --platform "$platform" --entrypoint /usr/local/bin/tclsh "$image" /dev/stdin <<EOF
set got "[info patchlevel] \$tcl_platform(machine)"
if {\$got ne "$version $machine"} { puts stderr "FAIL: \$got, want $version $machine"; exit 1 }
# 8.5 needs --enable-threads; Tcl 9 dropped tcl_platform(threaded) because it is always threaded
if {![info exists tcl_platform(threaded)] && ![package vsatisfies [info tclversion] 9-]} {
	puts stderr "FAIL: not threaded"; exit 1
}
if {[package vsatisfies [info tclversion] 8.6-]} {
	package require Thread
	package require sqlite3
	if {[zlib decompress [zlib compress hello]] ne "hello"} { puts stderr "FAIL: zlib"; exit 1 }
}
if {![file exists /usr/local/share/licenses/tcl/license.terms]} { puts stderr "FAIL: license missing"; exit 1 }
puts "ok $image: \$got"
EOF
