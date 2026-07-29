# opencode-cli: Terminal-based AI code editor
# 使用 lib/binary.nix 构建
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
import ../../lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } {
  pname = "opencode";
  version = "1.18.7";
  url = "https://github.com/anomalyco/opencode/releases/download/v1.18.7/opencode-linux-x64.tar.gz";
  hash = "sha256-y12dbS+PvvCpyXXtRJT3Oypi9OT/1Qi8wyEtpPp2w9o=";
  binaryName = "opencode";
  binName = "opencode";
  customWrapper = ''
    #!/bin/sh
    OPENCODE_BIN="$out/share/opencode/opencode"
    # opencode 使用 Bun 编译，Bun 会拦截 --help 标志
    # 这个 wrapper 修复了这个问题
    case "$1" in
      --help|-h)
        exec "$OPENCODE_BIN" help 2>/dev/null || exec "$OPENCODE_BIN" --no-help-banner help 2>/dev/null || exec "$OPENCODE_BIN"
        ;;
      *)
        exec "$OPENCODE_BIN" "$@"
        ;;
    esac
  '';
  meta = {
    description = "Terminal-based AI code editor";
    homepage = "https://opencode.ai/";
    license = lib.licenses.mit;
  };
}
