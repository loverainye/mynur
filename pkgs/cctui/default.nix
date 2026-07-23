{ lib, buildGoModule, fetchFromGitHub, ... }:

buildGoModule rec {
  pname = "cctui";
  version = "2026.04.04";

  src = fetchFromGitHub {
    owner = "manateelazycat";
    repo = "cctui";
    rev = "7556ec18d407";
    hash = "sha256-J3/JIywmrHc+IB9E0Ya+YAahHlP3n/+N5gYWiQqA9Bc=";
  };

  vendorHash = "sha256-XarYEugMpHUuxjcJCYjSl4QfVfgARtw6WXxBmwc+y5w=";

  meta = with lib; {
    description = "命令行 AI 供应商切换工具 - 管理并切换 Claude、Codex、Gemini 的多套供应商配置";
    homepage = "https://github.com/manateelazycat/cctui";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "cctui";
    maintainers = with maintainers; [ ytz ];
  };
}