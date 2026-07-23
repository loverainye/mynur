# mimode-cli: MiMo Code - AI-powered code editor
# 使用 lib/binary.nix 构建
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
import ../../lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } {
  pname = "mimode";
  version = "0.1.7";
  url = "https://github.com/XiaomiMiMo/MiMo-Code/releases/download/v0.1.7/mimocode-linux-x64.tar.gz";
  hash = "sha256-H+tiDnRVIs1Dc3Cc7ZwVbcId1HAXP+tuVIIiGcOYCBQ=";
  binaryName = "mimo";
  binName = "mimo";
  meta = {
    description = "MiMo Code - AI-powered code editor based on OpenCode";
    homepage = "https://github.com/XiaomiMiMo/MiMo-Code";
    license = lib.licenses.unfree;
  };
}
