# Triton Inference Server - Nix Build

Build NVIDIA Triton Inference Server v2.66.0 from source using Flox/Nix.

## Prerequisites

- [Flox](https://flox.dev) installed
- NVIDIA GPU with CUDA 12.8 drivers
- ~32 GB disk space for build artifacts
- ~16 GB RAM recommended (build is memory-intensive)

## Quick Start

```bash
git add .flox/pkgs/triton-server.nix
flox build triton-server
```

Build output appears at `./result-triton-server/`.

## Build Output

```
result-triton-server/
  bin/
    tritonserver          # Main server binary (18 MB)
    simple                # Example: single model
    multi_server          # Example: multiple server instances
    memory_alloc          # Example: custom memory allocation
  lib/
    libtritonserver.so    # Core runtime library (7.4 MB)
    libtritonbackendutils.a
    libtritoncommonmodelconfig.a
    libkernel_library_new.a
    ...                   # + 5 more static libs
    stubs/libtritonserver.so
    cmake/TritonCore/     # CMake find_package support
    cmake/TritonBackend/  # Backend development cmake modules
    cmake/TritonCommon/   # Common utilities cmake modules
  include/
    *.pb.h                # 5 protobuf/gRPC service definitions
    triton/core/          # 4 headers: C API, backend, cache, repo agent
    triton/backend/       # 7 headers: backend development utilities
    triton/common/        # 9 headers: shared utilities (logging, JSON, etc.)
  python/
    tritonserver-*.whl    # Python in-process API bindings
    tritonfrontend-*.whl  # Python HTTP/gRPC frontend bindings
    tritonserver-*.tar.gz # Source tarball
```

## Usage

```bash
# Run the server
./result-triton-server/bin/tritonserver \
  --model-repository=/path/to/models \
  --http-port=8000 \
  --grpc-port=8001 \
  --metrics-port=8002

# Check it works
./result-triton-server/bin/tritonserver --help
```

## Building Custom Backends

The build output includes everything needed to develop custom Triton backends:
- Headers in `include/triton/backend/` and `include/triton/common/`
- CMake integration via `find_package(TritonBackend)` and `find_package(TritonCommon)`
- Stub library at `lib/stubs/libtritonserver.so` for linking without the full runtime

Point your backend's CMake at the build output:

```bash
cmake -DCMAKE_PREFIX_PATH=./result-triton-server/lib/cmake ...
```

## What's Included

| Feature | Status |
|---------|--------|
| HTTP endpoint | Enabled |
| gRPC endpoint | Enabled |
| GPU support (CUDA) | Enabled |
| Logging | Enabled |
| Statistics | Enabled |
| CPU Metrics | Enabled |
| GPU Metrics | Disabled (requires DCGM) |
| Model Ensembles | Enabled |
| Cloud storage (GCS/S3/Azure) | Disabled |
| Tracing | Disabled |

### CUDA Architectures

Built for: Ampere (sm_80, sm_86), Ada Lovelace (sm_89), Hopper (sm_90).

Newer GPUs (Blackwell sm_100+) work via PTX JIT compilation.

## Build Details

The Nix expression at `.flox/pkgs/triton-server.nix` pre-fetches 12 GitHub
repositories and patches Triton's CMake build to work in Nix's sandboxed (no-network)
environment. Key adaptations:

- All `FetchContent` and `ExternalProject` git clones replaced with pre-fetched sources
- `gcc14Stdenv` used for CUDA 12.8 compatibility (default gcc15 is unsupported)
- Python wheel build uses `--no-isolation` with loosened dependency version pins
- `/etc/os-release` references stubbed (doesn't exist in Nix sandbox)
- `lib64` paths normalized to `lib` (GNUInstallDirs x86_64 default vs Triton expectation)
- Tests disabled (they require network access to fetch googletest)

## Nix Build Parallelism

The build spawns parallel cmake sub-builds. If you run out of memory, adjust
`/etc/nix/flox.conf`:

```
max-jobs = 4
cores = 2
```

`max-jobs` = concurrent derivations, `cores` = threads per derivation.

## Upgrading

To build a different Triton version:

1. Edit `.flox/pkgs/triton-server.nix`
2. Update `version` and `tag` at the top
3. Clear all `fetchFromGitHub` `hash` fields (set to `""`)
4. Run `flox build` repeatedly - each failure prints the correct hash
5. Fix any new build errors (new deps, changed cmake structure, etc.)

See `CLAUDE.md` for detailed notes on every sandbox challenge encountered.

## License

Triton Inference Server is licensed under BSD-3-Clause by NVIDIA Corporation.
