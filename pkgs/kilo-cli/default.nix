# kilo-cli: Kilo Code CLI - Terminal-based AI coding assistant
# 使用 lib/binary.nix 构建
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
import ../../lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } {
  pname = "kilo-cli";
  version = "7.4.11";
  url = "https://github.com/Kilo-Org/kilocode/releases/download/v7.4.11/kilo-linux-x64.tar.gz";
  hash = "sha256-sGDdTglLD5lm3gPYoNDVzI5rsjqwTx0Et+OVHRMHl3A=";
  binaryName = "kilo";
  binName = "kilo";
  extraFiles = ''
    cp -r tree-sitter $out/share/kilo-cli/
  '';
  customWrapper = ''
    #!/bin/sh
    export KILO_BIN="$out/share/kilo-cli/kilo"
    exec "$KILO_BIN" "$@"
  '';
  meta = {
    description = "Kilo Code CLI - Terminal-based AI coding assistant";
    homepage = "https://kilo.ai";
    license = lib.licenses.unfree;
  };
}
