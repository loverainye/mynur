# cc-switch-cli: CLI manager for Claude Code, Codex, Gemini, OpenCode, and OpenClaw
# 使用 lib/binary.nix 构建
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
import ../../lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } rec {
  pname = "cc-switch-cli";
  version = "5.10.1";
  url = "https://github.com/SaladDay/cc-switch-cli/releases/download/v${version}/cc-switch-cli-v${version}-linux-x64-musl.tar.gz";
  hash = "sha256-vmg260LPZ0ezgwsV2HkC/GoTMcNSY6p1kO0KN6RDB5A=";
  binaryName = "cc-switch";
  binName = "cc-switch-cli";
  usePatchelf = false;  # musl binary, 无需 patchelf
  meta = {
    description = "CLI manager for Claude Code, Codex, Gemini, OpenCode, and OpenClaw";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    license = lib.licenses.mit;
  };
}
