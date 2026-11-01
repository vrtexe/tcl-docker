#!/usr/bin/env bash
# Smoke-test one image on the machine's own architecture:
#   ./test.sh <image> <tcl-version>        ENGINE=podman ./test.sh ...
#   PLATFORM=linux/amd64 ./test.sh ...     test another architecture under emulation
#   TARGET=dev ./test.sh ...               a -dev image: also build and load a C extension
# Checks version, CPU, threading (8.5 off, 8.6 on), and that bundled packages and zlib load (8.6+).
# tclsh is set as the entrypoint so the same test also runs on the shell-less distroless variant.
set -euo pipefail
image=$1 version=$2
engine=${ENGINE:-docker}
target=${TARGET:-runtime}
case "${PLATFORM:-$(uname -m)}" in
	linux/amd64 | x86_64) platform=linux/amd64 machine=x86_64 ;;
	linux/arm64 | arm64 | aarch64) platform=linux/arm64 machine=aarch64 ;;
	*) echo "unsupported platform: ${PLATFORM:-$(uname -m)}" >&2; exit 1 ;;
esac

"$engine" run --rm -i --platform "$platform" --entrypoint /usr/local/bin/tclsh "$image" /dev/stdin <<EOF
set got "[info patchlevel] \$tcl_platform(machine)"
if {\$got ne "$version $machine"} { puts stderr "FAIL: \$got, want $version $machine"; exit 1 }
# 8.5 is built non-threaded (upstream's default), 8.6 threaded; Tcl 9 is always threaded and
# dropped tcl_platform(threaded)
if {![package vsatisfies [info tclversion] 9-]} {
	set threaded [expr {[info exists tcl_platform(threaded)] && \$tcl_platform(threaded)}]
	set want [package vsatisfies [info tclversion] 8.6-]
	if {\$threaded != \$want} { puts stderr "FAIL: threaded=\$threaded, want \$want"; exit 1 }
}
if {[package vsatisfies [info tclversion] 8.6-]} {
	package require Thread
	package require sqlite3
	if {[zlib decompress [zlib compress hello]] ne "hello"} { puts stderr "FAIL: zlib"; exit 1 }
}
# Tcl 8.5's configure probe can wrongly decide the C stack grows up, which disables its stack check
set cfg [open /usr/local/lib/tclConfig.sh]
if {[string match *TCL_STACK_GROWS_UP=1* [read \$cfg]]} { puts stderr "FAIL: TCL_STACK_GROWS_UP=1"; exit 1 }
close \$cfg
if {![file exists /usr/local/share/licenses/tcl/license.terms]} { puts stderr "FAIL: license missing"; exit 1 }
# images with a shell also provide /usr/bin/tclsh for scripts with a hardcoded #! line
if {[file exists /bin/sh]
		&& ([catch {file readlink /usr/bin/tclsh} link] || \$link ne "/usr/local/bin/tclsh")} {
	puts stderr "FAIL: /usr/bin/tclsh is not a link to /usr/local/bin/tclsh"; exit 1
}
if {"$target" eq "dev"} {
	foreach tool {make gcc curl} {
		if {[auto_execok \$tool] eq ""} { puts stderr "FAIL: \$tool missing"; exit 1 }
	}
	# what -dev is for: compile an extension against the stubs library and load it
	set f [open /tmp/hello.c w]
	puts \$f {
		#include <tcl.h>
		static int Hi(void *cd, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
			Tcl_SetObjResult(interp, Tcl_NewStringObj("hi", -1));
			return TCL_OK;
		}
		int Hello_Init(Tcl_Interp *interp) {
			if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) return TCL_ERROR;
			Tcl_CreateObjCommand(interp, "hello", Hi, NULL, NULL);
			return Tcl_PkgProvide(interp, "Hello", "1.0");
		}
	}
	close \$f
	exec gcc -shared -fPIC -DUSE_TCL_STUBS -I/usr/local/include -o /tmp/libhello.so /tmp/hello.c \\
		{*}[glob /usr/local/lib/libtclstub*.a]
	load /tmp/libhello.so Hello
	if {[hello] ne "hi"} { puts stderr "FAIL: extension"; exit 1 }
}
puts "ok $image ($target): \$got"
EOF
