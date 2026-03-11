# trtllm-tools-libs-ml: TensorRT + MKL native libs for TRT-LLM tools
#
# Contains: TensorRT 10.13 (libnvinfer, libnvonnxparser) and
# Intel MKL/TBB/OpenMP runtime libraries.
#
# ~3.5 GB uncompressed (under 5 GB catalog limit)
{ pkgs ? import <nixpkgs> {} }:

let
  pname = "trtllm-tools-libs-ml";
  version = "2.66.0";

  parts = import ./trtllm-tools-parts.nix { inherit pkgs; };

in pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = parts.bundlePart0;

  sourceRoot = ".";
  unpackPhase = ''
    mkdir -p source
    ${parts.catParts parts} | tar -xzf - -C source \
      --wildcards \
      'lib/libnvinfer*' \
      'lib/libnvonnxparser*' \
      'lib/libmkl*' \
      'lib/libtbb*' \
      'lib/libtbbbind*' \
      'lib/libtbbmalloc*' \
      'lib/libiomp*' \
      'lib/libiompstubs*' \
      2>/dev/null || true
    cd source
  '';

  nativeBuildInputs = [ pkgs.patchelf ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -P lib/*.so lib/*.so.* $out/lib/ 2>/dev/null || true

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
    description = "TensorRT and MKL libraries for TRT-LLM tools";
    homepage = "https://github.com/NVIDIA/TensorRT-LLM";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
