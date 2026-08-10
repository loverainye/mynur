#!/usr/bin/env bash
# check-updates.sh — 检查 mynur 自定义包的 GitHub 上游版本
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKGS_DIR="$REPO_ROOT/pkgs"

# 格式: "包名|owner/repo|当前版本前缀"
# 版本前缀: GitHub release tag 通常以 v 开头 (如 v1.18.4)，但 default.nix 中 version 字段不含 v
PACKAGES=(
  "codex|openai/codex|0."
  "claude-code|anthropics/claude-code|2."
  "opencode-cli|anomalyco/opencode|1."
  "opencode-gui|anomalyco/opencode|1."
  "mimode-cli|XiaomiMiMo/MiMo-Code|0."
  "antigravity|google-antigravity/antigravity|2."
  "antigravity-cli|google-antigravity/antigravity-cli|1."
  "cc-switch-cli|SaladDay/cc-switch-cli|5."
  "cc-switch-gui|farion1231/cc-switch|3."
  "cctui|manateelazycat/cctui|20"
  "kilo-cli|Kilo-Org/kilocode|7."
  "oh-my-opencode|code-yeongyu/oh-my-openagent|4."
  "rustdesk|rustdesk/rustdesk|1."
  "warpd|loverainye/warpd|unstable"
)

# 从 default.nix 提取当前版本
get_current_version() {
  local pkg="$1"
  local nix_file="$PKGS_DIR/$pkg/default.nix"
  if [ ! -f "$nix_file" ]; then
    echo "N/A"
    return
  fi
  grep -oP 'version\s*=\s*"\K[^"]+' "$nix_file" 2>/dev/null || echo "N/A"
}

# 获取 GitHub 最新 release tag
get_latest_release() {
  local repo="$1"
  local prefix="$2"
  # 用 gh CLI (CI 中有 GITHUB_TOKEN)
  if command -v gh &>/dev/null; then
    gh release list --repo "$repo" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo ""
  else
    curl -sf "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null || echo ""
  fi
}

has_updates=false
updates=""

for entry in "${PACKAGES[@]}"; do
  IFS='|' read -r pkg repo version_prefix <<< "$entry"
  current=$(get_current_version "$pkg")
  latest=$(get_latest_release "$repo" "$version_prefix")

  if [ -z "$latest" ]; then
    echo "⚠️  $pkg: 无法获取最新版本"
    continue
  fi

  # 去掉 tag 的 v 前缀进行比较
  latest_clean="${latest#v}"

  if [ "$current" = "$latest_clean" ]; then
    echo "✅ $pkg: $current (已是最新)"
  else
    echo "🔄 $pkg: $current → $latest_clean"
    has_updates=true
    updates+="$(echo "$pkg: $current → $latest_clean")"$'\n'
  fi
done

echo ""
if [ "$has_updates" = true ]; then
  echo "发现更新:"
  echo "$updates"
else
  echo "所有包已是最新版本"
fi

# --apply 模式: 更新 default.nix 中的版本号
if [ "${1:-}" = "--apply" ]; then
  echo ""
  echo "=== 应用更新 ==="
  for entry in "${PACKAGES[@]}"; do
    IFS='|' read -r pkg repo version_prefix <<< "$entry"
    current=$(get_current_version "$pkg")
    latest=$(get_latest_release "$repo" "$version_prefix")
    latest_clean="${latest#v}"

    if [ -z "$latest_clean" ] || [ "$current" = "$latest_clean" ]; then
      continue
    fi

    nix_file="$PKGS_DIR/$pkg/default.nix"
    if [ -f "$nix_file" ]; then
      sed -i "s|version = \"$current\"|version = \"$latest_clean\"|" "$nix_file"
      echo "📝 $pkg: $current → $latest_clean"
    fi
  done
fi
