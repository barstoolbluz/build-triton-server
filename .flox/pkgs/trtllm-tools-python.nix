# trtllm-tools-python: Python 3.12 interpreter + stdlib + most dist-packages
#
# Contains everything in python/ EXCEPT torch, torchgen, torchprofile,
# torchvision, and tensorrt_llm (those are in trtllm-tools-engine).
#
# ~4.3 GB uncompressed, ~2.5 GB as NAR.zst (under 5 GB catalog limit)
{ pkgs ? import <nixpkgs> {} }:

let
  pname = "trtllm-tools-python";
  version = "2.66.0";

  parts = import ./trtllm-tools-parts.nix { inherit pkgs; };

in pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = parts.bundlePart0;

  sourceRoot = ".";
  unpackPhase = ''
    mkdir -p source
    # Exclude engine directories (no globs — safe with nullglob)
    ${parts.catParts parts} | tar -xzf - -C source \
      --exclude=python/dist-packages/torch \
      --exclude=python/dist-packages/torchgen \
      --exclude=python/dist-packages/torchprofile \
      --exclude=python/dist-packages/torchvision \
      --exclude=python/dist-packages/torchvision.libs \
      --exclude=python/dist-packages/tensorrt_llm \
      python/
    cd source
    # Remove dist-info dirs for engine packages (glob patterns don't work
    # in tar --exclude because Nix stdenv sets nullglob, which silently
    # removes unmatched glob arguments before tar sees them)
    rm -rf python/dist-packages/torch-*.dist-info \
           python/dist-packages/torchprofile-*.dist-info \
           python/dist-packages/torchvision-*.dist-info \
           python/dist-packages/tensorrt_llm-*.dist-info
  '';

  nativeBuildInputs = [ pkgs.patchelf ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -a python $out/python

    # Fix broken symlinks from container layout
    rm -f $out/python/lib/python3.12/config-3.12-x86_64-linux-gnu/libpython3.12.so
    rm -f $out/python/lib/python3.12/sitecustomize.py

    runHook postInstall
  '';

  postFixup = ''
    # ---- python/bin/python3.12 ----
    patchelf --set-rpath '$ORIGIN/../../lib' \
      $out/python/bin/python3.12 2>/dev/null || true

    # ---- python/lib/python3.12/lib-dynload/*.so ----
    for f in $out/python/lib/python3.12/lib-dynload/*.so; do
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN/../../../../lib' "$f" 2>/dev/null || true
    done

    # ---- tensorrt/tensorrt.so ----
    if [ -f "$out/python/dist-packages/tensorrt/tensorrt.so" ]; then
      patchelf --set-rpath '$ORIGIN:$ORIGIN/../../../../lib' \
        "$out/python/dist-packages/tensorrt/tensorrt.so" 2>/dev/null || true
    fi

    # ---- flash_attn *.so ----
    find $out/python/dist-packages/flash_attn -name '*.so' 2>/dev/null | while read f; do
      patchelf --set-rpath '$ORIGIN:$ORIGIN/../../../../../lib' "$f" 2>/dev/null || true
    done

    # ---- triton *.so ----
    find $out/python/dist-packages/triton -name '*.so' 2>/dev/null | while read f; do
      patchelf --set-rpath '$ORIGIN:$ORIGIN/../../../../../lib' "$f" 2>/dev/null || true
    done

    # ---- pydantic_core *.so ----
    for f in $out/python/dist-packages/pydantic_core/*.so; do
      [ -f "$f" ] || continue
      patchelf --set-rpath '$ORIGIN:$ORIGIN/../../../../lib' "$f" 2>/dev/null || true
    done

    # ---- All *.libs/ directories ----
    # Nix fixup converts DT_RPATH → DT_RUNPATH, which doesn't propagate to
    # transitive deps.  Set $ORIGIN so bundled libs in *.libs/ dirs find their
    # siblings (numpy.libs, pillow.libs, scipy.libs, h5py.libs, pyzmq.libs, etc.)
    for libdir in $out/python/dist-packages/*.libs; do
      [ -d "$libdir" ] || continue
      for f in "$libdir"/*.so*; do
        [ -L "$f" ] && continue
        [ -f "$f" ] || continue
        patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
      done
    done
  '';

  dontStrip = true;

  meta = with pkgs.lib; {
    description = "Python 3.12 interpreter and packages for TRT-LLM tools";
    homepage = "https://github.com/NVIDIA/TensorRT-LLM";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
