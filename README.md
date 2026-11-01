# Tcl container images

Tcl built from the official source releases for `linux/amd64` and `linux/arm64`, on Debian,
Alpine, Rocky Linux and distroless.

These are community images. They are not published by the Tcl Core Team.

## Versions

| Version | Status |
|---|---|
| 9.1.0 | current (`latest`) |
| 9.0.4 | current 9.0 |
| 8.6.18 | current 8.6 (`8`) |
| 8.5.19 | last 8.5 release; 8.5 is unsupported upstream since 2016 |
| 8.5.13 | legacy, pinned for applications that require exactly this patch level (`package require -exact Tcl 8.5.13`); use 8.5.19 otherwise |

Every version is built threaded and as a shared library, with the bundled packages
(Thread, sqlite3, TDBC, itcl on 8.6+). Debian and Alpine also package Tcl
(`apt install tcl8.6`, `apk add tcl`); these images exist for the newest patch releases,
for 9.1, and for 8.5, which no distribution ships any more.

## Variants

| Variant | Tag suffix | Base | Size (8.6) | Use |
|---|---|---|---|---|
| Debian | none, `-trixie` | `buildpack-deps:trixie` | ~1.1 GB | default; includes gcc and the Tcl headers, for building extensions |
| Debian slim | `-slim` | `debian:trixie-slim` | ~117 MB | runtime |
| Alpine | `-alpine` | `alpine:3.24` | ~23 MB | smallest with a shell |
| Rocky Linux 9 | `-rocky9-minimal` | `quay.io/rockylinux/rockylinux:9-minimal` | ~182 MB | RHEL-family systems |
| Rocky Linux 8 | `-rocky8-minimal` | `quay.io/rockylinux/rockylinux:8-minimal` | ~113 MB | older RHEL-family systems |
| distroless | `-distroless` | `gcr.io/distroless/cc-debian13` | ~47 MB | no shell, no package manager; `tclsh` is the entrypoint |

Sizes are uncompressed, measured on arm64.

Debian slim, Alpine and both Rocky Linux variants also come as `-dev` images: the same Tcl
plus `make`, `gcc`, the C library and zlib headers, and `curl`. Build an extension on the
`-dev` image, then copy the result into the matching runtime image; both share the same
Tcl build and C library. The Debian image needs no `-dev` tag (it already has the
toolchain), and distroless has none by design (build on `slim-dev` instead).

Each tag holds both architectures; `docker pull` picks the one matching the host,
`--platform linux/arm64` picks one explicitly.

## Tags

Every image is tagged `<version>-<variant>`. Shorter aliases follow the newest release:
`<minor>-<variant>` points to the newest patch of that minor version, `<major>-<variant>`
to the newest of that major version, and the bare variant name to the newest overall.
Alpine as the example:

| Tcl | Tags |
|---|---|
| 8.5.13 | `8.5.13-alpine` `8.5.13-alpine3.24` |
| 8.5.19 | `8.5.19-alpine` `8.5.19-alpine3.24` `8.5-alpine` `8.5-alpine3.24` |
| 8.6.18 | `8.6.18-alpine` `8.6.18-alpine3.24` `8.6-alpine` `8.6-alpine3.24` `8-alpine` `8-alpine3.24` |
| 9.0.4 | `9.0.4-alpine` `9.0.4-alpine3.24` `9.0-alpine` `9.0-alpine3.24` |
| 9.1.0 | `9.1.0-alpine` `9.1.0-alpine3.24` `9.1-alpine` `9.1-alpine3.24` `9-alpine` `9-alpine3.24` `alpine` `alpine3.24` |

The other variants follow the same pattern with their own suffix:

- Debian: no suffix or `-trixie`, so `8.6`, `8.6.18`, `9` and `latest` are the Debian image.
- Debian slim: `-slim` or `-slim-trixie` (`8.6-slim`, `slim`).
- Rocky Linux and distroless: `-rocky9-minimal`, `-rocky8-minimal`, `-distroless`
  (`8.6-rocky8-minimal`, `distroless`).
- `-dev` images: every tag of the runtime image plus `-dev` (`8.6-alpine-dev`,
  `8.5.13-rocky8-minimal-dev`, `slim-dev`).

Choosing a tag:

- `8.5-alpine` is 8.5.19, the newest 8.5. Applications that require an exact patch level,
  such as `package require -exact Tcl 8.5.13`, need the full version: `8.5.13-alpine`.
- `-alpine` and `-slim` move to the next distribution release once the images adopt it;
  `-alpine3.24` and `-slim-trixie` stay on that release.
- All tags, including exact versions, are rebuilt monthly to pick up operating system
  security fixes, so their content changes while the Tcl version stays the same. To freeze
  an image completely, pin its digest: `tcl:8.5.13-alpine@sha256:<digest>`.

Published to Docker Hub (`docker.io/<user>/tcl`) and the GitHub Container Registry
(`ghcr.io/<owner>/tcl`) with identical tags and digests.

## Usage

```sh
docker run -it --rm <user>/tcl:8.6                                  # interactive tclsh
docker run --rm -v "$PWD":/app -w /app <user>/tcl:8.6-slim tclsh app.tcl
docker run --rm -v "$PWD":/app -w /app <user>/tcl:8.6-distroless app.tcl   # distroless: arguments go to tclsh
```

As a base image:

```dockerfile
FROM <user>/tcl:8.6-slim
COPY app.tcl /app/
CMD ["tclsh", "/app/app.tcl"]
```

Building a C extension on `-dev` and shipping it on the runtime image:

```dockerfile
FROM <user>/tcl:8.6-alpine-dev AS build
COPY myext.c /src/
RUN gcc -shared -fPIC -DUSE_TCL_STUBS -I/usr/local/include \
      -o /src/libmyext.so /src/myext.c /usr/local/lib/libtclstub8.6.a

FROM <user>/tcl:8.6-alpine
COPY --from=build /src/libmyext.so /usr/local/lib/myext/
```

Scripts with a hardcoded `#!/usr/bin/tclsh` line work as-is: every image with a shell
links `/usr/bin/tclsh` to the installed `tclsh`.

On distroless, `exec` can only run what is in the image; scripts that call `exec ls` and
similar need another variant.

## Binary tarballs

Each GitHub Release also carries the binaries outside a container image:

| File | Built on | Runs on |
|---|---|---|
| `tcl-<version>-linux-<arch>-glibc.tar.gz` | Rocky Linux 8 (glibc 2.28) | glibc 2.28 or newer: Debian 10+, Ubuntu 20.04+, RHEL/Rocky 8+ |
| `tcl-<version>-linux-<arch>-musl.tar.gz` | Alpine 3.24 | Alpine and other musl systems |
| `tcl<version>-src.tar.gz` | — | the unmodified official source each build used, checked against `versions.json` |

They are built for `/usr/local`:

```sh
sha256sum -c tcl-8.6.18-linux-arm64-glibc.tar.gz.sha256
sudo tar -xzf tcl-8.6.18-linux-arm64-glibc.tar.gz -C /usr/local --strip-components=1
# RHEL-family systems do not search /usr/local/lib by default:
echo /usr/local/lib | sudo tee /etc/ld.so.conf.d/usr-local.conf && sudo ldconfig
```

## Repository layout

The layout follows the official Docker images:

- `versions.json` is the only place that lists versions, checksums and variants.
- `Dockerfile-<family>.template` holds one build recipe per distribution family.
- `apply-templates.sh` renders `<version>/<variant>/Dockerfile`. The rendered files are
  committed, so each one can be read and built on its own:
  `docker build 8.6.18/alpine3.24`.
- `tags.sh <version> <variant>` prints the tags for one image.
- `test.sh <image> <version>` smoke-tests an image on the host architecture;
  `TARGET=dev` also compiles and loads a C extension.

To add or update a version: edit `versions.json`, run `./apply-templates.sh`, commit both.

## Building locally

```sh
docker build -t tcl-local 8.6.18/alpine3.24
./test.sh tcl-local 8.6.18
docker build --target dev -t tcl-local-dev 8.6.18/alpine3.24
TARGET=dev ./test.sh tcl-local-dev 8.6.18

# another architecture, under emulation (Docker Desktop, colima with Rosetta, or QEMU)
docker build --platform linux/amd64 -t tcl-local 8.6.18/alpine3.24
PLATFORM=linux/amd64 ./test.sh tcl-local 8.6.18

# podman
podman build --platform linux/arm64 -t tcl-local 8.6.18/alpine3.24
ENGINE=podman ./test.sh tcl-local 8.6.18
```

Pass `--platform` to podman even for the native architecture: without it, podman may reuse
a cached base image of another architecture.

## CI

- `.github/workflows/build.yml` builds every version and variant natively on amd64 and arm64
  runners and runs `test.sh` on each. Pushes to `main`, the monthly rebuild and manual runs
  publish multi-arch tags to GHCR, then a single job mirrors them to Docker Hub with
  `skopeo` (one image at a time, which stays within Docker Hub's rate limits). It needs the
  repository variable `DOCKERHUB_USERNAME` and the secret `DOCKERHUB_TOKEN` (a Docker Hub
  access token); GHCR uses the workflow's own `GITHUB_TOKEN`. After the first push, set the
  `tcl` package to public under the package settings.
- `.github/workflows/release.yml` runs on `v*` tags (for example `v2026.11.0`). It builds and
  tests the tarball variants from the tagged commit and creates the GitHub Release with the
  binary tarballs and the Tcl sources. It publishes no images.

## License

The files in this repository (Dockerfiles, templates, scripts) are under the MIT License,
see [LICENSE](LICENSE).

Tcl itself is distributed under its own BSD-style license; each image and tarball carries
it at `/usr/local/share/licenses/tcl/license.terms`.
