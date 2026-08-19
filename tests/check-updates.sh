#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
cat > "$tmp_dir/bin/gh" <<'EOF'
#!/usr/bin/env bash
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
  openai/codex) printf '%s\n' rust-v0.148.0 ;;
  anthropics/claude-code) printf '%s\n' v2.1.235 ;;
  anomalyco/opencode) printf '%s\n' v1.18.18 ;;
  XiaomiMiMo/MiMo-Code) printf '%s\n' v0.1.12 ;;
  google-antigravity/antigravity-cli) printf '%s\n' 1.1.14 ;;
  SaladDay/cc-switch-cli) printf '%s\n' v5.10.2 ;;
  farion1231/cc-switch) printf '%s\n' v3.20.0 ;;
  Kilo-Org/kilocode) printf '%s\n' jetbrains/v7.0.16 v7.4.22 ;;
  code-yeongyu/oh-my-openagent) printf '%s\n' v5.0.0-beta.10 ;;
  rustdesk/rustdesk) printf '%s\n' 1.4.9 ;;
esac
EOF
chmod +x "$tmp_dir/bin/gh"
cat > "$tmp_dir/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '[]\n'
EOF
chmod +x "$tmp_dir/bin/curl"

output=$(PATH="$tmp_dir/bin:$PATH" \
  CHATGPT_PACKAGES_FILE="$repo_root/tests/fixtures/chatgpt-Packages" \
  "$repo_root/scripts/check-updates.sh")

grep -q '^CHECK_UPDATES_FAILED=false$' <<< "$output"
grep -q '^CHECK_UPDATES_HAS_APPLYABLE_UPDATES=false$' <<< "$output"
grep -q '^🔄 kilo-cli: .* → 7.4.22$' <<< "$output"
grep -q '^🔄 oh-my-opencode: .* → 5.0.0-beta.10$' <<< "$output"
if grep -q 'antigravity: 无法获取' <<< "$output"; then
  echo "不支持 GitHub Release 的 antigravity 不应参与通用检查" >&2
  exit 1
fi

set +e
failure_output=$(PATH="$tmp_dir/bin:$PATH" \
  MOCK_FAIL_REPO=openai/codex \
  CHATGPT_PACKAGES_FILE="$repo_root/tests/fixtures/chatgpt-Packages" \
  "$repo_root/scripts/check-updates.sh" 2>&1)
failure_status=$?
set -e
if [ "$failure_status" -eq 0 ]; then
  echo "上游查询失败时脚本应返回非零状态" >&2
  exit 1
fi
grep -q '^CHECK_UPDATES_FAILED=true$' <<< "$failure_output"
grep -q '^CHECK_UPDATES_FAILURES=codex: 无法获取匹配前缀 rust-v0\. 的最新版本;' <<< "$failure_output"

echo "check-updates tests passed"
