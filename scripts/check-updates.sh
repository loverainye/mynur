#!/usr/bin/env bash
# check-updates.sh — 检查 mynur 自定义包的上游版本
set -euo pipefail

REPO_ROOT="${CHECK_UPDATES_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PKGS_DIR="$REPO_ROOT/pkgs"
CHATGPT_PACKAGES_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages.gz"

# 格式: "包名|owner/repo|当前版本前缀"
# 版本前缀: GitHub release tag 通常以 v 开头 (如 v1.18.4)，但 default.nix 中 version 字段不含 v
PACKAGES=(
  "codex|openai/codex|rust-v0."
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

has_updates=false
has_applyable_updates=false
check_failed=false
updates=""
declare -A latest_release_cache
declare -A latest_versions
latest_release_result=""
chatgpt_metadata_loaded=false
chatgpt_latest=""
chatgpt_sri=""

# 工作流使用这些标记，不依赖中文摘要文本判断状态。
print_status_markers() {
  echo "CHECK_UPDATES_HAS_UPDATES=$has_updates"
  echo "CHECK_UPDATES_HAS_APPLYABLE_UPDATES=$has_applyable_updates"
  echo "CHECK_UPDATES_FAILED=$check_failed"
}

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
  local cache_key="$repo|$prefix"
  if [[ -v "latest_release_cache[$cache_key]" ]]; then
    latest_release_result="${latest_release_cache[$cache_key]}"
    return
  fi
  local result=""
  if command -v gh &>/dev/null; then
    result=$(gh release list --repo "$repo" --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")
  fi
  if [ -z "$result" ]; then
    local auth_header=""
    local github_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    if [ -n "$github_token" ]; then
      auth_header="Authorization: token $github_token"
    fi
    result=$(curl -sf -H "$auth_header" "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null || echo "")
  fi
  latest_release_cache["$cache_key"]="$result"
  latest_release_result="$result"
}

normalize_github_version() {
  local tag="$1"
  local prefix="$2"
  local version="${tag#v}"
  if [[ ! "$version" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]] || [[ "$version" != "$prefix"* ]]; then
    return 1
  fi
  echo "$version"
}

# 读取并严格校验官方 Debian Packages 元数据；不读取 .deb。
load_chatgpt_metadata() {
  if [ "$chatgpt_metadata_loaded" = true ]; then
    return 0
  fi
  chatgpt_metadata_loaded=true

  local packages_file="${CHATGPT_PACKAGES_FILE:-}"
  if [ -n "$packages_file" ]; then
    if [ ! -f "$packages_file" ]; then
      echo "⚠️  chatgpt: CHATGPT_PACKAGES_FILE 不存在: $packages_file"
      check_failed=true
      return 1
    fi
  else
    packages_file=$(mktemp)
    if ! curl -fsSL \
      --retry 3 \
      --retry-all-errors \
      --connect-timeout 10 \
      --max-time 30 \
      "$CHATGPT_PACKAGES_URL" > "$packages_file"; then
      rm -f "$packages_file"
      echo "⚠️  chatgpt: 无法获取官方 Packages.gz"
      check_failed=true
      return 1
    fi
  fi

  local metadata
  if ! metadata=$(python3 - "$packages_file" <<'PY'
import base64
import gzip
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
raw = path.read_bytes()
try:
    text = gzip.decompress(raw).decode("utf-8")
except (OSError, UnicodeDecodeError):
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise SystemExit("Packages 元数据不是有效的 gzip 或 UTF-8 文件")

for stanza in re.split(r"\n\s*\n", text):
    fields = {}
    for line in stanza.splitlines():
        if ": " in line:
            key, value = line.split(": ", 1)
            fields[key] = value
    if fields.get("Package") != "chatgpt" or fields.get("Architecture") != "amd64":
        continue
    version = fields.get("Version", "")
    sha256 = fields.get("SHA256", "")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
        raise SystemExit("chatgpt Version 不是点分数字版本")
    if not re.fullmatch(r"[0-9a-fA-F]{64}", sha256):
        raise SystemExit("chatgpt SHA256 不是 64 位十六进制值")
    digest = bytes.fromhex(sha256)
    sri = "sha256-" + base64.b64encode(digest).decode("ascii")
    print(f"{version}\t{sha256.lower()}\t{sri}")
    break
else:
    raise SystemExit("Packages 元数据中没有有效的 chatgpt amd64 stanza")
PY
  ); then
    echo "⚠️  chatgpt: Packages 元数据校验失败"
    check_failed=true
    [ -n "${CHATGPT_PACKAGES_FILE:-}" ] || rm -f "$packages_file"
    return 1
  fi

  [ -n "${CHATGPT_PACKAGES_FILE:-}" ] || rm -f "$packages_file"
  IFS=$'\t' read -r chatgpt_latest _ chatgpt_sri <<< "$metadata"
}

apply_nix_update() {
  local nix_file="$1"
  local old_version="$2"
  local new_version="$3"
  local new_hash="$4"
  python3 - "$nix_file" "$old_version" "$new_version" "$new_hash" <<'PY'
import os
import re
import sys
import tempfile
from pathlib import Path

path, old_version, new_version, new_hash = sys.argv[1:]
text = Path(path).read_text(encoding="utf-8")
version_old = f'version = "{old_version}"'
version_new = f'version = "{new_version}"'
if text.count(version_old) != 1 or text.count("hash = ") != 1:
    raise SystemExit("Nix 文件中的版本或 hash 字段不是唯一可替换项")
text = text.replace(version_old, version_new, 1)
hash_match = re.search(r'(?m)^(\s*hash\s*=\s*)"[^"\n]+"', text)
if hash_match is None:
    raise SystemExit("Nix 文件中没有有效的 hash 字段")
text = text[:hash_match.start()] + f'{hash_match.group(1)}"{new_hash}"' + text[hash_match.end():]
directory = str(Path(path).parent)
fd, temporary = tempfile.mkstemp(prefix=f".{Path(path).name}.", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as output:
        output.write(text)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, path)
except BaseException:
    try:
        os.unlink(temporary)
    except FileNotFoundError:
        pass
    raise
PY
}

if [ "${CHECK_UPDATES_ONLY:-}" != "chatgpt" ]; then
  for entry in "${PACKAGES[@]}"; do
    IFS='|' read -r pkg repo version_prefix <<< "$entry"
    current=$(get_current_version "$pkg")
    get_latest_release "$repo" "$version_prefix"
    latest="$latest_release_result"
    latest_versions["$pkg"]="$latest"

    if [ -z "$latest" ]; then
      echo "⚠️  $pkg: 无法获取最新版本"
      check_failed=true
      continue
    fi

    if ! latest_clean=$(normalize_github_version "$latest" "$version_prefix"); then
      echo "⚠️  $pkg: 上游版本格式无效: $latest"
      check_failed=true
      continue
    fi

    if [ "$current" = "$latest_clean" ]; then
      echo "✅ $pkg: $current (已是最新)"
    else
      echo "🔄 $pkg: $current → $latest_clean"
      has_updates=true
      if [ -f "$PKGS_DIR/$pkg/default.nix" ]; then
        has_applyable_updates=true
      fi
      updates+="$pkg: $current → $latest_clean"$'\n'
    fi
  done
fi

current_chatgpt=$(get_current_version "chatgpt")
if load_chatgpt_metadata; then
  if [ "$current_chatgpt" = "$chatgpt_latest" ]; then
    echo "✅ chatgpt: $current_chatgpt (已是最新)"
  else
    echo "🔄 chatgpt: $current_chatgpt → $chatgpt_latest"
    has_updates=true
    if [ -f "$PKGS_DIR/chatgpt/default.nix" ]; then
      has_applyable_updates=true
    fi
    updates+="chatgpt: $current_chatgpt → $chatgpt_latest"$'\n'
  fi
fi

echo ""
if [ "$has_updates" = true ]; then
  echo "发现更新:"
  echo "$updates"
elif [ "$check_failed" = true ]; then
  echo "更新检查失败"
else
  echo "所有包已是最新版本"
fi
print_status_markers

# --apply 模式: 只应用已成功获取且同时包含版本和 hash 的更新
if [ "${1:-}" = "--apply" ]; then
  echo ""
  echo "=== 应用更新 ==="
  if [ "$check_failed" = true ]; then
    echo "检查存在失败，未修改任何包。" >&2
    exit 1
  fi
  if [ "${CHECK_UPDATES_ONLY:-}" != "chatgpt" ]; then
    for entry in "${PACKAGES[@]}"; do
      IFS='|' read -r pkg repo version_prefix <<< "$entry"
      current=$(get_current_version "$pkg")
      latest="${latest_versions[$pkg]:-}"
      latest_clean=$(normalize_github_version "$latest" "$version_prefix")

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
  if [ "$has_applyable_updates" = true ] && [ -n "$chatgpt_latest" ] && [ "$current_chatgpt" != "$chatgpt_latest" ]; then
    apply_nix_update "$PKGS_DIR/chatgpt/default.nix" "$current_chatgpt" "$chatgpt_latest" "$chatgpt_sri"
    echo "📝 chatgpt: $current_chatgpt → $chatgpt_latest (版本与 hash 已同步更新)"
  fi
fi

if [ "$check_failed" = true ]; then
  exit 1
fi
