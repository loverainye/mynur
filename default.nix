{ pkgs ? import <nixpkgs> { } }:

{
  codex = pkgs.callPackage ./pkgs/codex { };
  claude-code = pkgs.callPackage ./pkgs/claude-code { };
  opencode-cli = pkgs.callPackage ./pkgs/opencode-cli { };
  opencode-gui = pkgs.callPackage ./pkgs/opencode-gui { };
  mimode-cli = pkgs.callPackage ./pkgs/mimode-cli { };
  antigravity = pkgs.callPackage ./pkgs/antigravity { };
  antigravity-cli = pkgs.callPackage ./pkgs/antigravity-cli { };
  qoder = pkgs.callPackage ./pkgs/qoder { };
  qoder-cli = pkgs.callPackage ./pkgs/qoder-cli { };
  cc-switch-cli = pkgs.callPackage ./pkgs/cc-switch-cli { };
  cc-switch-gui = pkgs.callPackage ./pkgs/cc-switch-gui { };
  cctui = pkgs.callPackage ./pkgs/cctui { };
  kilo-cli = pkgs.callPackage ./pkgs/kilo-cli { };
  oh-my-opencode = pkgs.callPackage ./pkgs/oh-my-opencode { };
  opencode-bridge = pkgs.callPackage ./pkgs/opencode-bridge { };
  graphify = pkgs.callPackage ./pkgs/graphify { };
  dingtalk = pkgs.callPackage ./pkgs/dingtalk { };
  duckdb-odbc = pkgs.callPackage ./pkgs/duckdb-odbc { };
  warpd = pkgs.callPackage ./pkgs/warpd { };
  rustdesk = pkgs.callPackage ./pkgs/rustdesk { };
  v2rayn = pkgs.callPackage ./pkgs/v2rayn { };
  daed = pkgs.callPackage ./pkgs/daed { };
  xdg-desktop-portal-generic = pkgs.callPackage ./pkgs/xdg-desktop-portal-generic { };
  qwen-code = pkgs.callPackage ./pkgs/qwen-code { };
}
