# mimode-cli: MiMo Code - AI-powered code editor
# 使用 lib/binary.nix 构建
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
import ../../lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } rec {
  pname = "mimode";
  version = "0.1.12";
  url = "https://github.com/XiaomiMiMo/MiMo-Code/releases/download/v${version}/mimocode-linux-x64.tar.gz";
  hash = "sha256-6IFFpMOsgXtrSnXtEFRXGnyKF73vMCFCQ2MNPs/2iqQ=";
  binaryName = "mimo";
  binName = "mimo";
  meta = {
    description = "MiMo Code - AI-powered code editor based on OpenCode";
    homepage = "https://github.com/XiaomiMiMo/MiMo-Code";
    license = lib.licenses.unfree;
  };
}
