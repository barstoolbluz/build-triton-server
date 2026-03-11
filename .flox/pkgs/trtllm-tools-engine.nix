# trtllm-tools-engine: PyTorch + TensorRT-LLM Python packages
#
# Contains: torch, torchgen, torchprofile, torchvision, torchvision.libs,
# tensorrt_llm and their dist-info directories.
#
# ~4.1 GB uncompressed, ~2.5 GB as NAR.zst (under 5 GB catalog limit)
{ pkgs ? import <nixpkgs> {} }:

let
  pname = "trtllm-tools-engine";
  version = "2.66.0";

  parts = import ./trtllm-tools-parts.nix { inherit pkgs; };

in pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = parts.bundlePart0;

  sourceRoot = ".";
  unpackPhase = ''
    mkdir -p source
    ${parts.catParts parts} | tar -xzf - -C source \
      python/dist-packages/torch \
      python/dist-packages/torchgen \
      python/dist-packages/torchprofile \
      python/dist-packages/torchvision \
      python/dist-packages/torchvision.libs \
      python/dist-packages/tensorrt_llm
    # dist-info dirs (tar doesn't glob, so extract with wildcard via shell)
    ${parts.catParts parts} | tar -xzf - -C source \
      --wildcards \
      'python/dist-packages/torch-*' \
      'python/dist-packages/torchprofile-*' \
      'python/dist-packages/torchvision-*' \
      'python/dist-packages/tensorrt_llm-*' \
      2>/dev/null || true
    cd source
  '';

  nativeBuildInputs = [ pkgs.patchelf ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/dist-packages
    cp -a python/dist-packages/torch $out/dist-packages/
    cp -a python/dist-packages/torchgen $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/torchprofile $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/torchvision $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/torchvision.libs $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/tensorrt_llm $out/dist-packages/

    # dist-info
    cp -a python/dist-packages/torch-*.dist-info $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/torchprofile-*.dist-info $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/torchvision-*.dist-info $out/dist-packages/ 2>/dev/null || true
    cp -a python/dist-packages/tensorrt_llm-*.dist-info $out/dist-packages/ 2>/dev/null || true

    runHook postInstall
  '';

  postFixup = ''
    # ---- torch/lib/*.so ----
    for f in $out/dist-packages/torch/lib/*.so*; do
      [ -L "$f" ] && continue
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
    done

    # ---- tensorrt_llm/libs/*.so ----
    for f in $out/dist-packages/tensorrt_llm/libs/*.so; do
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
    done
    for f in $out/dist-packages/tensorrt_llm/libs/nixl/*.so \
             $out/dist-packages/tensorrt_llm/libs/nixl/plugins/*.so; do
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
    done

    # ---- torchvision.libs *.so ----
    for f in $out/dist-packages/torchvision.libs/*.so*; do
      [ -L "$f" ] && continue
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
    done
  '';

  dontStrip = true;

  meta = with pkgs.lib; {
    description = "PyTorch and TensorRT-LLM packages for TRT-LLM tools";
    homepage = "https://github.com/NVIDIA/TensorRT-LLM";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
