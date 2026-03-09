# CLAUDE.md - Build Triton Server from Source

## Project Overview

This is a Flox Nix expression build of NVIDIA Triton Inference Server v2.66.0 (r26.02)
from source. The build output is at `./result-triton-server/`.

## Key Files

- `.flox/pkgs/triton-server.nix` - The Nix expression (primary deliverable)
- `.flox/env/manifest.toml` - Flox manifest (minimal, just for `flox build`)
- `result-triton-server/` - Build output symlink

## Build Command

```bash
cd /home/daedalus/dev/builds/build-triton-server
git add .flox/pkgs/triton-server.nix   # Flox requires tracked files
flox build triton-server
```

## Architecture Decisions

### Why Nix Expression (not Manifest Build)
Triton's build is too complex for a manifest `[build]` section. It requires:
- 12 pre-fetched GitHub repos (fixed-output derivations)
- Python patching script (`builtins.toFile`)
- Multiple `substituteInPlace` passes across 4 repos
- `gcc14Stdenv` override (default gcc15 incompatible with CUDA 12.8)

### Why gcc14Stdenv
CUDA 12.8's nvcc rejects gcc >= 15. Using `gcc14Stdenv` instead of default `stdenv`
ensures the entire build (including ExternalProject sub-builds) uses gcc 14.

### Why Tests Are Disabled
Tests in core, common, and server/src all try to `FetchContent` googletest from
GitHub. No network in Nix sandbox. Disabling is safe since we're packaging, not
developing.

### Why METRICS_GPU=OFF
`TRITON_ENABLE_METRICS_GPU` requires DCGM (NVIDIA Data Center GPU Manager), which
isn't packaged in Nix. The server works fine without it - just no GPU power/utilization
metrics via Prometheus.

### CUDA Architectures: 80;86;89;90
The backend repo's `define.cuda_architectures.cmake` defaults to `100f;120f` which
nvcc 12.8 doesn't support (CMake 4.x forward-compatibility syntax). We pin to
80/86/89/90. Forward compat for newer GPUs (Blackwell) works via PTX JIT.

## Critical Nix Sandbox Challenges (and solutions)

### 1. No Network Access
Triton's CMake uses `FetchContent` and `ExternalProject_Add` to clone repos at build
time. Solutions:
- **FetchContent repos**: Pre-fetched via `fetchFromGitHub` (FODs), injected via
  `FETCHCONTENT_SOURCE_DIR_*` cmake vars + `FETCHCONTENT_FULLY_DISCONNECTED=ON`
- **ExternalProject (third_party)**: Python patch script replaces `GIT_REPOSITORY`
  with `DOWNLOAD_COMMAND ""` and remaps paths to pre-fetched local copies
- **Python wheel build**: `--no-isolation` flag prevents pip from downloading deps

### 2. ExternalProject Sub-Builds Don't Inherit CMake Vars
`FETCHCONTENT_SOURCE_DIR_*` set at the top-level cmake DON'T propagate into
ExternalProject sub-builds (separate cmake processes). Fix:
- **triton-core ExternalProject**: Patched `CMAKE_CACHE_ARGS` in core/CMakeLists.txt
- **triton-server ExternalProject**: Injected `set(... CACHE ...)` calls into
  server/src/CMakeLists.txt after `include(FetchContent)`

### 3. Read-Only Nix Store Paths
`fetchFromGitHub` results land in `/nix/store/` (read-only). Triton's build patches
sources in-place. Fix: `cp -r` to `$TMPDIR/` writable copies for core, common,
third_party, and all prefetched deps.

### 4. /etc/os-release Doesn't Exist in Sandbox
Four CMakeLists.txt files read `/etc/os-release` to detect CentOS (for lib64). All
patched via `substituteInPlace` to `set(DISTRO_ID_LIKE "")`.

### 5. lib64 vs lib
GNUInstallDirs defaults to `lib64` on x86_64. Triton's third_party cmake expects
`lib`. Fix: Python patch script injects `-DCMAKE_INSTALL_LIBDIR:STRING=lib` into
every ExternalProject. Also `preFixup` merges any remaining lib64 into lib.

### 6. Python Wheel Version Pins
`pyproject.toml` pins `setuptools==75.3.0`, `wheel==0.44.0`, etc. Nix provides
different versions. Fix: `substituteInPlace` to loosen all pins. Also patched
`"numpy<2"` to `"numpy"` (Nix has numpy 2.x).

## Pre-Fetched Repos (12 total)

| Repo | Version | Notes |
|------|---------|-------|
| server | r26.02 | Main source (src=) |
| core | r26.02 | Writable copy needed |
| common | r26.02 | Writable copy needed |
| backend | r26.02 | Read-only OK (no patching) |
| third_party | r26.02 | Writable copy, heavily patched |
| pybind11 | v2.13.1 | Read-only OK |
| grpc | v1.54.3 | fetchSubmodules=true (abseil, protobuf, re2, cares) |
| libevent | release-2.1.12-stable | |
| prometheus-cpp | v1.0.1 | |
| nlohmann-json | v3.11.3 | |
| curl | curl-7_86_0 | |
| crc32c | b9d6e825... | |

## Upgrading to a New Triton Version

1. Update `tag` and `version` in the nix expression
2. Set all `fetchFromGitHub` hashes to `""` (empty string)
3. Run `flox build triton-server` repeatedly - each failure gives the correct hash
4. Check for new `/etc/os-release` references, new test directories, new deps
5. The Python patch script and path mappings may need updates if third_party changes

## Nix Expression Gotchas

- **`''${` in Nix strings**: Literal `${` must be escaped as `''${` in `''...''` strings.
  The Python patch script uses `''${{CMAKE_CURRENT_BINARY_DIR}}` for this reason.
- **CMake semicolons in Nix**: Use `${"\\;"}` to produce a literal `\;` in cmake args
  (Nix eats the first level, cmake needs the backslash-semicolon)
- **`builtins.toFile`**: Creates a file in the Nix store from a string. Used for the
  Python patch script since it's too complex for inline bash.
- **`cmakeFlagsArray`**: Bash array - unlike `cmakeFlags` (Nix list), this preserves
  values containing `$TMPDIR` which is only known at build time.
