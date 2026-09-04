#!/usr/bin/env bash
# check-updates.sh — 检查 mynur 自定义包的上游版本
set -euo pipefail

REPO_ROOT="${CHECK_UPDATES_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PKGS_DIR="$REPO_ROOT/pkgs"
CHATGPT_PACKAGES_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages.gz"
CODEX_REPO="openai/codex"
CODEX_VERSION_PREFIX="rust-v0."
CODEX_TARGET="x86_64-unknown-linux-musl"
CODEX_ASSET="codex-package-${CODEX_TARGET}.tar.gz"
CODEX_CHECKSUMS_ASSET="codex-package_SHA256SUMS"
CODEX_RELEASE_BASE_URL="https://github.com/openai/codex/releases/download"
WORKBUDDY_UPDATE_URL="https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb"

# 格式: "包名|owner/repo|当前版本前缀|是否包含预发布版本"
# 版本前缀: GitHub release tag 通常以 v 开头 (如 v1.18.4)，但 default.nix 中 version 字段不含 v
# antigravity 使用 Google Storage 的不透明构建路径；cctui 和 warpd 固定 Git
# commit，三者都没有可供此脚本可靠查询的 GitHub Release，不能放进此列表。
PACKAGES=(
  "claude-code|anthropics/claude-code|2.|false"
  "opencode-cli|anomalyco/opencode|1.|false"
  "opencode-gui|anomalyco/opencode|1.|false"
  "mimode-cli|XiaomiMiMo/MiMo-Code|0.|false"
  "antigravity-cli|google-antigravity/antigravity-cli|1.|false"
  "cc-switch-cli|SaladDay/cc-switch-cli|5.|false"
  "cc-switch-gui|farion1231/cc-switch|3.|false"
  "kilo-cli|Kilo-Org/kilocode|7.|false"
  "oh-my-opencode|code-yeongyu/oh-my-openagent|5.|true"
  "rustdesk|rustdesk/rustdesk|1.|false"
)

has_updates=false
has_applyable_updates=false
check_failed=false
updates=""
failures=""
declare -A latest_release_cache
latest_release_result=""
codex_metadata_loaded=false
codex_tag=""
codex_latest=""
codex_sri=""
codex_update_available=false
chatgpt_metadata_loaded=false
chatgpt_latest=""
chatgpt_sri=""
chatgpt_update_available=false
workbuddy_metadata_loaded=false
workbuddy_latest=""
workbuddy_url=""
workbuddy_sri=""
workbuddy_apply_sri=""
workbuddy_update_available=false

# 工作流使用这些标记，不依赖中文摘要文本判断状态。
print_status_markers() {
  echo "CHECK_UPDATES_HAS_UPDATES=$has_updates"
  echo "CHECK_UPDATES_HAS_APPLYABLE_UPDATES=$has_applyable_updates"
  echo "CHECK_UPDATES_FAILED=$check_failed"
  printf 'CHECK_UPDATES_FAILURES=%s\n' "${failures//$'\n'/; }"
}

record_failure() {
  local message="$1"
  echo "⚠️  $message"
  failures+="$message"$'\n'
  check_failed=true
}

check_requested() {
  local pkg="$1"
  [ -z "${CHECK_UPDATES_ONLY:-}" ] || [ "$CHECK_UPDATES_ONLY" = "$pkg" ]
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

get_current_hash() {
  local pkg="$1"
  local nix_file="$PKGS_DIR/$pkg/default.nix"
  if [ ! -f "$nix_file" ]; then
    echo "N/A"
    return
  fi
  grep -oP 'hash\s*=\s*"\K[^"]+' "$nix_file" 2>/dev/null || echo "N/A"
}

# 获取 GitHub 最新 release tag
get_latest_release() {
  local repo="$1"
  local prefix="$2"
  local include_prereleases="$3"
  local cache_key="$repo|$prefix|$include_prereleases"
  if [[ -v "latest_release_cache[$cache_key]" ]]; then
    latest_release_result="${latest_release_cache[$cache_key]}"
    return
  fi
  local result="" tags=""
  if command -v gh &>/dev/null; then
    local release_args=(--repo "$repo" --exclude-drafts --limit 100 --json tagName --jq '.[].tagName')
    if [ "$include_prereleases" != true ]; then
      release_args+=(--exclude-pre-releases)
    fi
    tags=$(gh release list "${release_args[@]}" 2>/dev/null || true)
    while IFS= read -r tag; do
      if normalize_github_version "$tag" "$prefix" >/dev/null; then
        result="$tag"
        break
      fi
    done <<< "$tags"
  fi
  if [ -z "$result" ]; then
    local curl_args=(-sf)
    local github_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    if [ -n "$github_token" ]; then
      curl_args+=(-H "Authorization: token $github_token")
    fi
    result=$(curl "${curl_args[@]}" \
      "https://api.github.com/repos/$repo/releases?per_page=100" 2>/dev/null \
      | python3 -c '
import json, sys
prefix, include_prereleases = sys.argv[1], sys.argv[2] == "true"
for release in json.load(sys.stdin):
    tag = release.get("tag_name", "")
    version = tag[1:] if tag.startswith("v") else tag
    if not release.get("draft") and (include_prereleases or not release.get("prerelease")) and version.startswith(prefix):
        print(tag)
        break
' "$prefix" "$include_prereleases" 2>/dev/null || true)
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

load_codex_metadata() {
  if [ "$codex_metadata_loaded" = true ]; then
    return 0
  fi

  get_latest_release "$CODEX_REPO" "$CODEX_VERSION_PREFIX" false
  codex_tag="$latest_release_result"
  if [ -z "$codex_tag" ]; then
    record_failure "codex: 无法获取匹配前缀 $CODEX_VERSION_PREFIX 的最新版本"
    return 1
  fi
  if ! codex_latest=$(normalize_github_version "$codex_tag" "$CODEX_VERSION_PREFIX"); then
    record_failure "codex: 上游版本格式无效: $codex_tag"
    return 1
  fi

  local checksums_file="${CODEX_CHECKSUMS_FILE:-}"
  local checksums=""
  if [ -n "$checksums_file" ]; then
    if [ ! -f "$checksums_file" ]; then
      record_failure "codex: CODEX_CHECKSUMS_FILE 不存在: $checksums_file"
      return 1
    fi
    checksums=$(<"$checksums_file")
  elif ! checksums=$(curl -fsSL \
    --retry 3 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 30 \
    "$CODEX_RELEASE_BASE_URL/$codex_tag/$CODEX_CHECKSUMS_ASSET"); then
    record_failure "codex: 无法获取 $codex_tag 的校验清单"
    return 1
  fi

  if ! codex_sri=$(python3 - "$CODEX_ASSET" "$checksums" <<'PY'
import base64
import re
import sys

asset, checksums = sys.argv[1:]
matches = []
for line in checksums.splitlines():
    match = re.fullmatch(r"([0-9a-fA-F]{64})  (\S+)", line)
    if match is not None and match.group(2) == asset:
        matches.append(match.group(1).lower())
if len(matches) != 1:
    raise SystemExit(f"校验清单中 {asset} 必须恰好出现一次")
digest = bytes.fromhex(matches[0])
print("sha256-" + base64.b64encode(digest).decode("ascii"))
PY
  ); then
    record_failure "codex: $codex_tag 的校验清单格式无效"
    return 1
  fi
  codex_metadata_loaded=true
}

verify_codex_asset() {
  local asset_url="$CODEX_RELEASE_BASE_URL/$codex_tag/$CODEX_ASSET"
  local metadata=""
  if ! metadata=$(nix store prefetch-file --json "$asset_url"); then
    record_failure "codex: 无法预取 $codex_tag 的组合包"
    return 1
  fi

  local actual_hash=""
  if ! actual_hash=$(python3 - "$metadata" <<'PY'
import json
import sys

metadata = json.loads(sys.argv[1])
value = metadata.get("hash", "")
if not isinstance(value, str) or not value.startswith("sha256-"):
    raise SystemExit("prefetch 结果缺少 SHA256 SRI hash")
print(value)
PY
  ); then
    record_failure "codex: 组合包预取结果格式无效"
    return 1
  fi
  if [ "$actual_hash" != "$codex_sri" ]; then
    record_failure "codex: 组合包实际 hash 与校验清单不一致"
    return 1
  fi
}

version_is_newer() {
  local current="$1"
  local candidate="$2"
  [ "$current" = "N/A" ] && return 0
  python3 - "$current" "$candidate" <<'PY'
import re
import sys


def parse(version):
    match = re.fullmatch(
        r"([^0-9]*)([0-9]+(?:\.[0-9]+)*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?",
        version,
    )
    if match is None:
        raise SystemExit(f"无法比较版本: {version}")
    prefix, core, prerelease = match.groups()
    core_parts = tuple(int(part) for part in core.split("."))
    prerelease_parts = None if prerelease is None else tuple(prerelease.split("."))
    return prefix, core_parts, prerelease_parts


def compare_identifiers(left, right):
    for left_part, right_part in zip(left, right):
        if left_part == right_part:
            continue
        left_numeric = left_part.isdigit()
        right_numeric = right_part.isdigit()
        if left_numeric and right_numeric:
            return (int(left_part) > int(right_part)) - (int(left_part) < int(right_part))
        if left_numeric != right_numeric:
            return -1 if left_numeric else 1
        return (left_part > right_part) - (left_part < right_part)
    return (len(left) > len(right)) - (len(left) < len(right))


def compare(left, right):
    left_prefix, left_core, left_pre = parse(left)
    right_prefix, right_core, right_pre = parse(right)
    if left_prefix != right_prefix:
        return (left_prefix > right_prefix) - (left_prefix < right_prefix)
    width = max(len(left_core), len(right_core))
    left_core += (0,) * (width - len(left_core))
    right_core += (0,) * (width - len(right_core))
    if left_core != right_core:
        return (left_core > right_core) - (left_core < right_core)
    if left_pre is None or right_pre is None:
        return (left_pre is None) - (right_pre is None)
    return compare_identifiers(left_pre, right_pre)


raise SystemExit(0 if compare(sys.argv[2], sys.argv[1]) > 0 else 1)
PY
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
      record_failure "chatgpt: CHATGPT_PACKAGES_FILE 不存在: $packages_file"
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
      record_failure "chatgpt: 无法获取官方 Packages.gz"
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
    record_failure "chatgpt: Packages 元数据校验失败"
    [ -n "${CHATGPT_PACKAGES_FILE:-}" ] || rm -f "$packages_file"
    return 1
  fi

  [ -n "${CHATGPT_PACKAGES_FILE:-}" ] || rm -f "$packages_file"
  IFS=$'\t' read -r chatgpt_latest _ chatgpt_sri <<< "$metadata"
}

# 读取并严格校验 WorkBuddy 官方更新接口；不读取 .deb。
load_workbuddy_metadata() {
  if [ "$workbuddy_metadata_loaded" = true ]; then
    return 0
  fi
  workbuddy_metadata_loaded=true

  local metadata_file="${WORKBUDDY_METADATA_FILE:-}"
  local metadata=""
  if [ -n "$metadata_file" ]; then
    if [ ! -f "$metadata_file" ]; then
      record_failure "workbuddy: WORKBUDDY_METADATA_FILE 不存在: $metadata_file"
      return 1
    fi
    metadata=$(<"$metadata_file")
  elif ! metadata=$(curl -fsSL \
    --retry 3 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 30 \
    "$WORKBUDDY_UPDATE_URL"); then
    record_failure "workbuddy: 无法获取官方更新元数据"
    return 1
  fi

  local parsed_metadata=""
  if ! parsed_metadata=$(python3 - "$metadata" <<'PY'
import base64
import json
import re
import sys
from urllib.parse import urlparse

try:
    metadata = json.loads(sys.argv[1])
except (TypeError, json.JSONDecodeError) as error:
    raise SystemExit(f"JSON 格式无效: {error}")
if not isinstance(metadata, dict):
    raise SystemExit("顶层 JSON 必须是对象")

version = metadata.get("version")
url = metadata.get("url")
sha256 = metadata.get("sha256hash")
if not isinstance(version, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
    raise SystemExit("version 不是点分数字版本")
if not isinstance(url, str):
    raise SystemExit("url 必须是字符串")
parsed = urlparse(url)
if parsed.scheme != "https" or parsed.netloc != "download.codebuddy.cn" or not parsed.path.endswith(".deb"):
    raise SystemExit("url 不是受信任的 WorkBuddy deb 地址")
if not isinstance(sha256, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", sha256):
    raise SystemExit("sha256hash 不是 64 位十六进制值")

digest = bytes.fromhex(sha256)
print(f"{version}\t{url}\tsha256-" + base64.b64encode(digest).decode("ascii"))
PY
  ); then
    record_failure "workbuddy: 更新元数据校验失败"
    return 1
  fi
  IFS=$'\t' read -r workbuddy_latest workbuddy_url workbuddy_sri <<< "$parsed_metadata"
  workbuddy_apply_sri="$workbuddy_sri"
}

verify_workbuddy_asset() {
  local metadata=""
  if ! metadata=$(nix store prefetch-file --json "$workbuddy_url"); then
    record_failure "workbuddy: 无法预取 $workbuddy_latest 的 deb"
    return 1
  fi

  local actual_hash=""
  if ! actual_hash=$(python3 - "$metadata" <<'PY'
import json
import re
import sys

metadata = json.loads(sys.argv[1])
value = metadata.get("hash", "")
if not isinstance(value, str) or not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", value):
    raise SystemExit("prefetch 结果缺少 SHA256 SRI hash")
print(value)
PY
  ); then
    record_failure "workbuddy: deb 预取结果格式无效"
    return 1
  fi

  workbuddy_apply_sri="$actual_hash"
  if [ "$actual_hash" != "$workbuddy_sri" ]; then
    echo "⚠️  workbuddy: 接口 hash 与 CDN 实际 hash 不一致，应用实际 hash"
  fi
}

apply_nix_updates() {
  python3 - "$@" <<'PY'
import os
import re
import sys
import tempfile
from pathlib import Path

arguments = sys.argv[1:]
if not arguments or len(arguments) % 5 != 0:
    raise SystemExit("内部错误: 更新参数必须按文件、旧版本、新版本、hash、URL 分组")


def render(path, old_version, new_version, new_hash, new_url):
    text = path.read_text(encoding="utf-8")
    version_old = f'version = "{old_version}"'
    version_new = f'version = "{new_version}"'
    if text.count(version_old) != 1 or text.count("hash = ") != 1:
        raise SystemExit(f"{path}: 版本或 hash 字段不是唯一可替换项")
    text = text.replace(version_old, version_new, 1)
    hash_match = re.search(r'(?m)^(\s*hash\s*=\s*)"[^"\n]+"', text)
    if hash_match is None:
        raise SystemExit(f"{path}: 没有有效的 hash 字段")
    text = (
        text[:hash_match.start()]
        + f'{hash_match.group(1)}"{new_hash}"'
        + text[hash_match.end():]
    )
    if new_url:
        url_matches = list(re.finditer(r'(?m)^(\s*url\s*=\s*)"[^"\n]+"', text))
        if len(url_matches) != 1:
            raise SystemExit(f"{path}: URL 字段不是唯一可替换项")
        url_match = url_matches[0]
        text = (
            text[:url_match.start()]
            + f'{url_match.group(1)}"{new_url}"'
            + text[url_match.end():]
        )
    return text


updates = []
paths = []
for index in range(0, len(arguments), 5):
    path = Path(arguments[index])
    paths.append(path)
    updates.append((path, *arguments[index + 1:index + 5]))
if len(set(paths)) != len(paths):
    raise SystemExit("内部错误: 同一文件不能在一次事务中更新两次")

# 先完成所有解析和临时文件写入，再替换目标，避免格式错误造成半更新。
staged = []


def cleanup_staged():
    for item in staged:
        temporary = item["temporary"]
        if temporary is not None:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


try:
    for path, old_version, new_version, new_hash, new_url in updates:
        original = path.read_bytes()
        mode = path.stat().st_mode
        text = render(path, old_version, new_version, new_hash, new_url)
        fd, temporary = tempfile.mkstemp(
            prefix=f".{path.name}.", dir=str(path.parent), text=True
        )
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as output:
                output.write(text)
                output.flush()
                os.fsync(output.fileno())
            os.chmod(temporary, mode)
        except BaseException:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            raise
        staged.append({
            "path": path,
            "temporary": temporary,
            "original": original,
            "mode": mode,
        })
except BaseException:
    cleanup_staged()
    raise

committed = []
try:
    for item in staged:
        os.replace(item["temporary"], item["path"])
        item["temporary"] = None
        committed.append(item)
except BaseException as commit_error:
    rollback_errors = []
    for item in reversed(committed):
        path = item["path"]
        fd, rollback = tempfile.mkstemp(prefix=f".{path.name}.rollback.", dir=str(path.parent))
        try:
            with os.fdopen(fd, "wb") as output:
                output.write(item["original"])
                output.flush()
                os.fsync(output.fileno())
            os.chmod(rollback, item["mode"])
            os.replace(rollback, path)
        except BaseException as rollback_error:
            rollback_errors.append(f"{path}: {rollback_error}")
            try:
                os.unlink(rollback)
            except FileNotFoundError:
                pass
    if rollback_errors:
        raise RuntimeError(
            "更新提交失败且回滚不完整: " + "; ".join(rollback_errors)
        ) from commit_error
    raise
finally:
    cleanup_staged()
PY
}

current_codex=""
if check_requested "codex"; then
  current_codex=$(get_current_version "codex")
  if load_codex_metadata; then
    current_codex_hash=$(get_current_hash "codex")
    if [ "$current_codex" = "$codex_latest" ] && [ "$current_codex_hash" = "$codex_sri" ]; then
      echo "✅ codex: $current_codex (版本与 hash 均为最新)"
    elif [ "$current_codex" = "$codex_latest" ]; then
      echo "🔄 codex: $current_codex (hash 需要修正)"
      has_updates=true
      codex_update_available=true
      updates+="codex: $current_codex hash → release hash"$'\n'
    elif version_is_newer "$current_codex" "$codex_latest"; then
      echo "🔄 codex: $current_codex → $codex_latest"
      has_updates=true
      codex_update_available=true
      updates+="codex: $current_codex → $codex_latest"$'\n'
    else
      echo "✅ codex: $current_codex (高于上游 $codex_latest)"
    fi
    if [ "$codex_update_available" = true ] && [ -f "$PKGS_DIR/codex/default.nix" ]; then
      has_applyable_updates=true
    fi
  fi
fi

for entry in "${PACKAGES[@]}"; do
  IFS='|' read -r pkg repo version_prefix include_prereleases <<< "$entry"
  if ! check_requested "$pkg"; then
    continue
  fi
  current=$(get_current_version "$pkg")
  get_latest_release "$repo" "$version_prefix" "$include_prereleases"
  latest="$latest_release_result"

  if [ -z "$latest" ]; then
    record_failure "$pkg: 无法获取匹配前缀 $version_prefix 的最新版本"
    continue
  fi

  if ! latest_clean=$(normalize_github_version "$latest" "$version_prefix"); then
    record_failure "$pkg: 上游版本格式无效: $latest"
    continue
  fi

  if [ "$current" = "$latest_clean" ]; then
    echo "✅ $pkg: $current (已是最新)"
  elif version_is_newer "$current" "$latest_clean"; then
    echo "🔄 $pkg: $current → $latest_clean"
    has_updates=true
    updates+="$pkg: $current → $latest_clean"$'\n'
  else
    echo "✅ $pkg: $current (高于上游 $latest_clean)"
  fi
done

current_chatgpt=""
if check_requested "chatgpt"; then
  current_chatgpt=$(get_current_version "chatgpt")
  if load_chatgpt_metadata; then
    if [ "$current_chatgpt" = "$chatgpt_latest" ]; then
      echo "✅ chatgpt: $current_chatgpt (已是最新)"
    elif version_is_newer "$current_chatgpt" "$chatgpt_latest"; then
      echo "🔄 chatgpt: $current_chatgpt → $chatgpt_latest"
      has_updates=true
      chatgpt_update_available=true
      if [ -f "$PKGS_DIR/chatgpt/default.nix" ]; then
        has_applyable_updates=true
      fi
      updates+="chatgpt: $current_chatgpt → $chatgpt_latest"$'\n'
    else
      echo "✅ chatgpt: $current_chatgpt (高于上游 $chatgpt_latest)"
    fi
  fi
fi

current_workbuddy=""
if check_requested "workbuddy"; then
  current_workbuddy=$(get_current_version "workbuddy")
  if load_workbuddy_metadata; then
    if [ "$current_workbuddy" = "$workbuddy_latest" ]; then
      echo "✅ workbuddy: $current_workbuddy (已是最新)"
    elif version_is_newer "$current_workbuddy" "$workbuddy_latest"; then
      echo "🔄 workbuddy: $current_workbuddy → $workbuddy_latest"
      has_updates=true
      workbuddy_update_available=true
      if [ -f "$PKGS_DIR/workbuddy/default.nix" ]; then
        has_applyable_updates=true
      fi
      updates+="workbuddy: $current_workbuddy → $workbuddy_latest"$'\n'
    else
      echo "✅ workbuddy: $current_workbuddy (高于上游 $workbuddy_latest)"
    fi
  fi
fi

if [ "${1:-}" = "--apply" ] && [ "$codex_update_available" = true ]; then
  verify_codex_asset || true
fi
if [ "${1:-}" = "--apply" ] && [ "$workbuddy_update_available" = true ]; then
  verify_workbuddy_asset || true
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

# --apply 模式: 只应用已完成版本、hash 和下载校验的更新
if [ "${1:-}" = "--apply" ]; then
  echo ""
  echo "=== 应用更新 ==="
  if [ "$check_failed" = true ]; then
    echo "检查存在失败，未修改任何包。" >&2
    exit 1
  fi
  apply_arguments=()
  if [ "$codex_update_available" = true ]; then
    apply_arguments+=(
      "$PKGS_DIR/codex/default.nix"
      "$current_codex"
      "$codex_latest"
      "$codex_sri"
      ""
    )
  fi
  if [ "$chatgpt_update_available" = true ]; then
    apply_arguments+=(
      "$PKGS_DIR/chatgpt/default.nix"
      "$current_chatgpt"
      "$chatgpt_latest"
      "$chatgpt_sri"
      ""
    )
  fi
  if [ "$workbuddy_update_available" = true ]; then
    apply_arguments+=(
      "$PKGS_DIR/workbuddy/default.nix"
      "$current_workbuddy"
      "$workbuddy_latest"
      "$workbuddy_apply_sri"
      "$workbuddy_url"
    )
  fi
  if [ "${#apply_arguments[@]}" -gt 0 ]; then
    apply_nix_updates "${apply_arguments[@]}"
  fi
  if [ "$codex_update_available" = true ]; then
    if [ "$current_codex" = "$codex_latest" ]; then
      echo "📝 codex: $current_codex (hash 已同步修正)"
    else
      echo "📝 codex: $current_codex → $codex_latest (版本与 hash 已同步更新)"
    fi
  fi
  if [ "$chatgpt_update_available" = true ]; then
    echo "📝 chatgpt: $current_chatgpt → $chatgpt_latest (版本与 hash 已同步更新)"
  fi
  if [ "$workbuddy_update_available" = true ]; then
    echo "📝 workbuddy: $current_workbuddy → $workbuddy_latest (版本、hash 与 URL 已同步更新)"
  fi
fi

if [ "$check_failed" = true ]; then
  exit 1
fi
