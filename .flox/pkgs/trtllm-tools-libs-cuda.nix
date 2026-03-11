# trtllm-tools-libs-cuda: CUDA runtime + math libs for TRT-LLM tools
#
# Contains: CUDA 13 (cudart, cublas, cufft, cusolver, cusparse, curand, nvrtc,
# nvJitLink, nvvm, npp), cuDNN 9.14, NCCL, MPI, UCX, and misc native libs.
# Excludes TensorRT and MKL (those are in trtllm-tools-libs-ml).
#
# ~2.9 GB uncompressed (under 5 GB catalog limit)
{ pkgs ? import <nixpkgs> {} }:

let
  pname = "trtllm-tools-libs-cuda";
  version = "2.66.0";

  parts = import ./trtllm-tools-parts.nix { inherit pkgs; };

in pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = parts.bundlePart0;

  sourceRoot = ".";
  unpackPhase = ''
    mkdir -p source
    ${parts.catParts parts} | tar -xzf - -C source lib/
    # Remove TensorRT and MKL libs (those belong in trtllm-tools-libs-ml).
    # Cannot use tar --exclude with globs because Nix stdenv sets nullglob,
    # which silently removes unmatched glob arguments before tar sees them.
    cd source
    rm -f lib/libnvinfer* lib/libnvonnxparser* \
          lib/libmkl* lib/libtbb* lib/libtbbbind* lib/libtbbmalloc* \
          lib/libiomp* lib/libiompstubs*
  '';

  nativeBuildInputs = [ pkgs.patchelf ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -P lib/*.so lib/*.so.* $out/lib/ 2>/dev/null || true
    if [ -d lib/nvvm ]; then
      cp -a lib/nvvm $out/lib/
    fi

    runHook postInstall
  '';

  postFixup = ''
    for f in $out/lib/*.so $out/lib/*.so.*; do
      [ -L "$f" ] && continue
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
    done
  '';

  dontStrip = true;

  meta = with pkgs.lib; {
    description = "CUDA runtime and math libraries for TRT-LLM tools";
    homepage = "https://github.com/NVIDIA/TensorRT-LLM";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
