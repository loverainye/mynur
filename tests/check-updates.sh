#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

workflow="$repo_root/.github/workflows/check-updates.yml"
checkout_line=$(grep -n 'uses: actions/checkout@' "$workflow" | head -1 | cut -d: -f1)
install_nix_line=$(grep -n 'uses: cachix/install-nix-action@' "$workflow" | head -1 | cut -d: -f1)
check_line=$(grep -n 'name: Check for updates' "$workflow" | head -1 | cut -d: -f1)
if [ -z "$checkout_line" ] || [ -z "$install_nix_line" ] || [ -z "$check_line" ] \
  || [ "$checkout_line" -ge "$install_nix_line" ] \
  || [ "$install_nix_line" -ge "$check_line" ]; then
  echo "check-updates workflow 必须在 checkout 后、更新检查前安装 Nix" >&2
  exit 1
fi

mkdir -p "$tmp_dir/bin"
{
printf '#!%s\n' "$(command -v bash)"
cat <<'EOF'
set -euo pipefail
repo=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--repo" ]; then
    repo="$2"
    break
  fi
  shift
done
if [ "${MOCK_FAIL_REPO:-}" = "$repo" ]; then
  exit 0
fi
case "$repo" in
  openai/codex) printf '%s\n' "${MOCK_CODEX_VERSION:-rust-v0.150.1}" ;;
  anthropics/claude-code) printf '%s\n' v2.1.235 ;;
  anomalyco/opencode) printf '%s\n' v1.18.17 ;;
  XiaomiMiMo/MiMo-Code) printf '%s\n' v0.1.12 ;;
  google-antigravity/antigravity-cli) printf '%s\n' 1.1.14 ;;
  SaladDay/cc-switch-cli) printf '%s\n' v5.10.2 ;;
  farion1231/cc-switch) printf '%s\n' v3.20.0 ;;
  Kilo-Org/kilocode) printf '%s\n' jetbrains/v7.0.16 v7.4.22 ;;
  code-yeongyu/oh-my-openagent) printf '%s\n' "${MOCK_OH_MY_VERSION:-v5.0.0-beta.10}" ;;
  rustdesk/rustdesk) printf '%s\n' 1.4.9 ;;
esac
EOF
} > "$tmp_dir/bin/gh"
chmod +x "$tmp_dir/bin/gh"
{
printf '#!%s\n' "$(command -v bash)"
cat <<'EOF'
printf '[]\n'
EOF
} > "$tmp_dir/bin/curl"
chmod +x "$tmp_dir/bin/curl"
{
printf '#!%s\n' "$(command -v bash)"
cat <<'EOF'
set -euo pipefail
if [ "${1:-}" = "store" ] && [ "${2:-}" = "prefetch-file" ]; then
  printf '{"hash":"%s","storePath":"/nix/store/mock-codex-package"}\n' \
    "${MOCK_CODEX_PREFETCH_HASH:-sha256-ERERERERERERERERERERERERERERERERERERERERERE=}"
  exit 0
fi
exit 1
EOF
} > "$tmp_dir/bin/nix"
chmod +x "$tmp_dir/bin/nix"

codex_checksums="$repo_root/tests/fixtures/codex-package_SHA256SUMS"

output=$(PATH="$tmp_dir/bin:$PATH" \
  CODEX_CHECKSUMS_FILE="$codex_checksums" \
  CHATGPT_PACKAGES_FILE="$repo_root/tests/fixtures/chatgpt-Packages" \
  bash "$repo_root/scripts/check-updates.sh")

grep -q '^CHECK_UPDATES_FAILED=false$' <<< "$output"
grep -q '^CHECK_UPDATES_HAS_APPLYABLE_UPDATES=false$' <<< "$output"
grep -q '^✅ codex: rust-v0.150.1 (版本与 hash 均为最新)$' <<< "$output"
grep -q '^🔄 kilo-cli: .* → 7.4.22$' <<< "$output"
grep -q '^🔄 oh-my-opencode: .* → 5.0.0-beta.10$' <<< "$output"
grep -q '^✅ opencode-cli: 1.18.18 (高于上游 1.18.17)$' <<< "$output"
if grep -q '^🔄 opencode-cli:' <<< "$output"; then
  echo "不应把较旧的上游版本当作更新" >&2
  exit 1
fi
if grep -q 'antigravity: 无法获取' <<< "$output"; then
  echo "不支持 GitHub Release 的 antigravity 不应参与通用检查" >&2
  exit 1
fi

stable_output=$(PATH="$tmp_dir/bin:$PATH" \
  MOCK_OH_MY_VERSION=v5.0.0 \
  CODEX_CHECKSUMS_FILE="$codex_checksums" \
  CHATGPT_PACKAGES_FILE="$repo_root/tests/fixtures/chatgpt-Packages" \
  bash "$repo_root/scripts/check-updates.sh")
grep -q '^🔄 oh-my-opencode: 5.0.0-beta.7 → 5.0.0$' <<< "$stable_output"

set +e
failure_output=$(PATH="$tmp_dir/bin:$PATH" \
  MOCK_FAIL_REPO=openai/codex \
  CODEX_CHECKSUMS_FILE="$codex_checksums" \
  CHATGPT_PACKAGES_FILE="$repo_root/tests/fixtures/chatgpt-Packages" \
  bash "$repo_root/scripts/check-updates.sh" 2>&1)
failure_status=$?
set -e
if [ "$failure_status" -eq 0 ]; then
  echo "上游查询失败时脚本应返回非零状态" >&2
  exit 1
fi
grep -q '^CHECK_UPDATES_FAILED=true$' <<< "$failure_output"
grep -q '^CHECK_UPDATES_FAILURES=codex: 无法获取匹配前缀 rust-v0\. 的最新版本;' <<< "$failure_output"

codex_only_output=$(PATH="$tmp_dir/bin:$PATH" \
  CHECK_UPDATES_ONLY=codex \
  CODEX_CHECKSUMS_FILE="$codex_checksums" \
  bash "$repo_root/scripts/check-updates.sh")
grep -q '^✅ codex:' <<< "$codex_only_output"
if grep -Eq '^(✅|🔄|⚠️) (chatgpt|claude-code):' <<< "$codex_only_output"; then
  echo "CHECK_UPDATES_ONLY=codex 不应检查其他包" >&2
  exit 1
fi

update_checksums="$tmp_dir/codex-update-SHA256SUMS"
printf '%s  %s\n' \
  '1111111111111111111111111111111111111111111111111111111111111111' \
  'codex-package-x86_64-unknown-linux-musl.tar.gz' > "$update_checksums"
apply_root="$tmp_dir/apply-root"
mkdir -p "$apply_root/pkgs/codex"
cp "$repo_root/pkgs/codex/default.nix" "$apply_root/pkgs/codex/default.nix"
apply_output=$(PATH="$tmp_dir/bin:$PATH" \
  CHECK_UPDATES_ONLY=codex \
  CHECK_UPDATES_REPO_ROOT="$apply_root" \
  CODEX_CHECKSUMS_FILE="$update_checksums" \
  MOCK_CODEX_VERSION=rust-v0.151.0 \
  bash "$repo_root/scripts/check-updates.sh" --apply)
grep -q '^CHECK_UPDATES_HAS_APPLYABLE_UPDATES=true$' <<< "$apply_output"
grep -q 'version = "rust-v0.151.0"' "$apply_root/pkgs/codex/default.nix"
grep -q 'hash = "sha256-ERERERERERERERERERERERERERERERERERERERERERE="' \
  "$apply_root/pkgs/codex/default.nix"
grep -q 'version = "rust-v0.150.1"' "$repo_root/pkgs/codex/default.nix"

atomic_packages="$tmp_dir/chatgpt-atomic-Packages"
printf '%s\n' \
  'Package: chatgpt' \
  'Version: 99.0.0' \
  'Architecture: amd64' \
  'SHA256: 2222222222222222222222222222222222222222222222222222222222222222' \
  > "$atomic_packages"
atomic_root="$tmp_dir/atomic-root"
mkdir -p "$atomic_root/pkgs/codex" "$atomic_root/pkgs/chatgpt"
cp "$repo_root/pkgs/codex/default.nix" "$atomic_root/pkgs/codex/default.nix"
cp "$repo_root/pkgs/chatgpt/default.nix" "$atomic_root/pkgs/chatgpt/default.nix"
sed -i 's/^    hash = /    sha256 = /' "$atomic_root/pkgs/chatgpt/default.nix"
cp "$atomic_root/pkgs/codex/default.nix" "$tmp_dir/atomic-codex-before.nix"
cp "$atomic_root/pkgs/chatgpt/default.nix" "$tmp_dir/atomic-chatgpt-before.nix"
set +e
atomic_output=$(PATH="$tmp_dir/bin:$PATH" \
  CHECK_UPDATES_REPO_ROOT="$atomic_root" \
  CODEX_CHECKSUMS_FILE="$update_checksums" \
  CHATGPT_PACKAGES_FILE="$atomic_packages" \
  MOCK_CODEX_VERSION=rust-v0.151.0 \
  bash "$repo_root/scripts/check-updates.sh" --apply 2>&1)
atomic_status=$?
set -e
if [ "$atomic_status" -eq 0 ]; then
  echo "批量更新中任一文件无效时脚本应返回非零状态" >&2
  exit 1
fi
grep -q 'chatgpt/default.nix: 版本或 hash 字段不是唯一可替换项' <<< "$atomic_output"
cmp "$tmp_dir/atomic-codex-before.nix" "$atomic_root/pkgs/codex/default.nix"
cmp "$tmp_dir/atomic-chatgpt-before.nix" "$atomic_root/pkgs/chatgpt/default.nix"
if find "$atomic_root/pkgs" -name '.default.nix.*' -print -quit | grep -q .; then
  echo "批量更新失败后不应残留临时文件" >&2
  exit 1
fi

wrong_hash_root="$tmp_dir/wrong-hash-root"
mkdir -p "$wrong_hash_root/pkgs/codex"
cp "$repo_root/pkgs/codex/default.nix" "$wrong_hash_root/pkgs/codex/default.nix"
sed -i \
  's#sha256-AKunBPAp9twNlIvkB6dW4Ml8yEATL9aRNTssawpQWxc=#sha256-ERERERERERERERERERERERERERERERERERERERERERE=#' \
  "$wrong_hash_root/pkgs/codex/default.nix"
wrong_hash_output=$(PATH="$tmp_dir/bin:$PATH" \
  CHECK_UPDATES_ONLY=codex \
  CHECK_UPDATES_REPO_ROOT="$wrong_hash_root" \
  CODEX_CHECKSUMS_FILE="$codex_checksums" \
  bash "$repo_root/scripts/check-updates.sh")
grep -q '^🔄 codex: rust-v0.150.1 (hash 需要修正)$' <<< "$wrong_hash_output"
grep -q '^CHECK_UPDATES_HAS_APPLYABLE_UPDATES=true$' <<< "$wrong_hash_output"

invalid_checksums="$tmp_dir/codex-invalid-SHA256SUMS"
printf '%s\n' 'invalid checksum manifest' > "$invalid_checksums"
set +e
invalid_output=$(PATH="$tmp_dir/bin:$PATH" \
  CHECK_UPDATES_ONLY=codex \
  CODEX_CHECKSUMS_FILE="$invalid_checksums" \
  bash "$repo_root/scripts/check-updates.sh" 2>&1)
invalid_status=$?
set -e
if [ "$invalid_status" -eq 0 ]; then
  echo "Codex 校验清单无效时脚本应返回非零状态" >&2
  exit 1
fi
grep -q '^CHECK_UPDATES_FAILURES=codex: rust-v0.150.1 的校验清单格式无效;' <<< "$invalid_output"

prefetch_root="$tmp_dir/prefetch-root"
mkdir -p "$prefetch_root/pkgs/codex"
cp "$repo_root/pkgs/codex/default.nix" "$prefetch_root/pkgs/codex/default.nix"
cp "$prefetch_root/pkgs/codex/default.nix" "$tmp_dir/prefetch-before.nix"
set +e
prefetch_output=$(PATH="$tmp_dir/bin:$PATH" \
  CHECK_UPDATES_ONLY=codex \
  CHECK_UPDATES_REPO_ROOT="$prefetch_root" \
  CODEX_CHECKSUMS_FILE="$update_checksums" \
  MOCK_CODEX_VERSION=rust-v0.151.0 \
  MOCK_CODEX_PREFETCH_HASH=sha256-mismatch \
  bash "$repo_root/scripts/check-updates.sh" --apply 2>&1)
prefetch_status=$?
set -e
if [ "$prefetch_status" -eq 0 ]; then
  echo "组合包实际 hash 不匹配时脚本应返回非零状态" >&2
  exit 1
fi
grep -q '^CHECK_UPDATES_FAILURES=codex: 组合包实际 hash 与校验清单不一致;' <<< "$prefetch_output"
cmp "$tmp_dir/prefetch-before.nix" "$prefetch_root/pkgs/codex/default.nix"

echo "check-updates tests passed"
