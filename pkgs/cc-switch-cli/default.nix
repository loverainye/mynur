# cc-switch-cli: CLI manager for Claude Code, Codex, Gemini, OpenCode, and OpenClaw
# 使用 lib/binary.nix 构建
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
import ../../lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } {
  pname = "cc-switch-cli";
  version = "5.9.3";
  url = "https://github.com/SaladDay/cc-switch-cli/releases/download/v5.9.3/cc-switch-cli-v5.9.3-linux-x64-musl.tar.gz";
  hash = "sha256-pYHsJu/aeVGClJJDZl6nJdQgKcWLtLkTfQcIslWk+5E=";
  binaryName = "cc-switch";
  binName = "cc-switch-cli";
  usePatchelf = false;  # musl binary, 无需 patchelf
  meta = {
    description = "CLI manager for Claude Code, Codex, Gemini, OpenCode, and OpenClaw";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    license = lib.licenses.mit;
  };
}
