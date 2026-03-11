# TensorRT SDK — pre-built CUDA library from pinned nixpkgs
# Used as a dependency for triton-tensorrt-backend.nix
#
# Uses a standalone nixpkgs-pin pattern (not callPackage) because it overrides
# cudaPackages with a specific nixpkgs revision and CUDA 12.9 overlay.
# Flox handles both calling conventions.
{ pkgs ? import <nixpkgs> {} }:
let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0.tar.gz";
  }) {
    config = { allowUnfree = true; cudaSupport = true; };
    overlays = [ (final: prev: { cudaPackages = final.cudaPackages_12_9; }) ];
  };
in
  nixpkgs_pinned.cudaPackages.tensorrt
