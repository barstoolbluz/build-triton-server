# trtllm-tools-libs: Native shared libraries for TRT-LLM tools
#
# Contains: CUDA 13, cuDNN 9.14, TRT 10.13, MKL, NCCL, MPI, and all other
# native .so files needed by the Python packages in trtllm-tools-python and
# trtllm-tools-engine.
#
# ~6.4 GB uncompressed, ~3.5 GB as NAR.zst (under 5 GB catalog limit)
{ pkgs ? import <nixpkgs> {} }:

let
  pname = "trtllm-tools-libs";
  version = "2.66.0";

  parts = import ./trtllm-tools-parts.nix { inherit pkgs; };

in pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = parts.bundlePart0;

  sourceRoot = ".";
  unpackPhase = ''
    mkdir -p source
    ${parts.catParts parts} | tar -xzf - -C source lib/
    cd source
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
    description = "Native shared libraries for TRT-LLM tools (CUDA, cuDNN, TRT, MKL, NCCL)";
    homepage = "https://github.com/NVIDIA/TensorRT-LLM";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
