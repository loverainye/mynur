# AGENTS.md

## 项目结构

- `flake.nix`：定义 `x86_64-linux` 包、checks、默认 overlay 和 `nix-fast-build` app。
- `default.nix`：统一导出 `pkgs/` 下的全部自定义包。
- `overlay.nix`：将全部包暴露为 `pkgs.mynur.<package>`。
- `pkgs/<package>/default.nix`：每个软件包的 Nix derivation；补丁放在对应包的 `patches/` 中。
- `lib/binary.nix`：预编译二进制包共用的解包、依赖和包装辅助逻辑。
- `.github/workflows/build.yml`：主分支和 PR 的构建入口；成功构建的 store path 上传到 `mynur.cachix.org`。
- `.github/workflows/check-updates.yml`：检查并提交可更新的软件版本。
- `scripts/check-updates.sh`、`tests/`：版本检查逻辑及测试。

## 核心命令

```bash
# 查看 flake 输出
nix flake show --no-write-lock-file

# 仅做求值和检查，不构建
nix flake check --no-build

# 构建单个包
nix build .#<package> --print-build-logs

# 按 CI 方式并行构建全部 checks
nix run .#nix-fast-build -- \
  --flake .#checks.x86_64-linux \
  --skip-cached \
  --no-link \
  --fail-fast

# 验证自动更新检查
bash tests/check-updates.sh
```

## 编码与打包风格

- Nix 文件使用 2 空格缩进，包目录和属性名使用 kebab-case。
- 新包必须在 `default.nix` 中通过 `pkgs.callPackage ./pkgs/<package> { };` 导出。
- 优先固定稳定 release/tag，并使用 SRI 格式的 `hash`/`cargoHash`。
- 预编译包优先复用 `lib/binary.nix`；源码包遵循 nixpkgs 的 `stdenv.mkDerivation` 或对应语言 builder 惯例。
- 保持 derivation 可离线复现，禁止在 build phase 中临时下载依赖。
- 补充准确的 `meta.description`、`homepage`、`license`、`platforms` 和 `mainProgram`。
- 不随意更新 `flake.lock`；仅在确需升级 nixpkgs 时单独说明并提交。

## GitHub Actions 与二进制缓存

- 推送到 `main` 会触发 `.github/workflows/build.yml`。
- workflow 使用仓库 secret `CACHIX_AUTH_TOKEN` 将成功构建的闭包推送到 `mynur` Cachix。
- 本地消费缓存时使用：

```nix
nixConfig = {
  extra-substituters = [ "https://mynur.cachix.org" ];
  extra-trusted-public-keys = [
    "mynur.cachix.org-1:dux7DNomiNsTZj+8HsSNR9YOYSqDo/mzc594P129Ro8="
  ];
};
```

## 包更新流程

1. 从 GitHub Releases 或官方发布页确认最新稳定版本。
2. 用 `nix-prefetch-url --unpack <url>` 获取源码 hash。
3. 用 `nix hash to-sri --type sha256 <nix32-hash>` 转换为 SRI。
4. 更新版本和 hash，执行单包构建、`nix flake check --no-build` 与更新检查。
5. 使用 Conventional Commits 提交，例如 `feat(pkgs): add fcitx5-vinput`。

## 重要约束

- 禁止提交 token、私钥、cookie 或其他凭据；Cachix token 只能保存在 GitHub Actions secrets 中。
- 工作区可能已有用户修改，不覆盖、不回滚、不混入无关提交。
- `fcitx5-vinput` 是源码构建包，依赖 nixpkgs 的共享版 `sherpa-onnx`；升级时需同时验证 daemon 的动态库解析。
- 推送前至少确保目标包能构建，且 `nix flake check --no-build` 通过。
