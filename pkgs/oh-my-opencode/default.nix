{ pkgs, lib, fetchFromGitHub }:

let
  version = "4.19.0"; # 唯一版本源

  src = fetchFromGitHub {
    owner = "code-yeongyu";
    repo = "oh-my-openagent";
    rev = "v${version}";
    hash = "sha256-wSUIckQjAaiT86m5WIK2DJVWSIB8o4eBuwWQQyOZrp0=";
  };

  node_modules = pkgs.stdenv.mkDerivation {
    pname = "oh-my-opencode-node_modules";
    inherit version src;
    nativeBuildInputs = [ pkgs.nodejs pkgs.pnpm pkgs.cacert ];
    dontConfigure = true;
    patchPhase = ''
      # pnpm 需要 pnpm-workspace.yaml 来识别 workspace packages
      echo 'packages:
  - "packages/*"' > pnpm-workspace.yaml
    '';
    buildPhase = ''
      export HOME=$TMPDIR
      # 每请求超时 10 分钟（默认 60s，大包下载不够）
      pnpm install --no-frozen-lockfile --ignore-scripts --fetch-timeout 600000
    '';
    installPhase = ''
      rm -rf node_modules/.cache
      mkdir -p $out
      cp -R node_modules $out/
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHash = "sha256-LFDQodFeqwR8OesFIKEVP6Mg/cjiKmsCrdLyJR3a69c=";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "oh-my-opencode";
  inherit version src;

  nativeBuildInputs = [ pkgs.bun pkgs.nodejs pkgs.makeWrapper pkgs.git ];

  preBuild = ''
    export HOME=$TMPDIR
    rm -rf node_modules
    # 复制 node_modules 到可写位置（不能用 symlink，workspace symlink 相对路径会解析到 store 内）
    cp -r ${node_modules}/node_modules node_modules
    chmod -R u+w node_modules
    # 修复 shebang（不能在 node_modules 固定输出 derivation 中做，会引入 store path 引用）
    patchShebangs node_modules 2>/dev/null || true
    # 确保 root node_modules/.bin 在 PATH 中（子包构建需要 tsc 等工具）
    export PATH="$(pwd)/node_modules/.bin:$PATH"
    # 重建 workspace symlink 指向本地 packages（bun 创建的指向 ../../packages/xxx 在 store 中不存在）
    for pkg_dir in packages/*/; do
      if [ -f "$pkg_dir/package.json" ]; then
        # 从 package.json 读取包名（无 jq，用 grep + sed）
        scope=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$pkg_dir/package.json" | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
        if [ -n "$scope" ] && [ -L "node_modules/$scope" ]; then
          rm -f "node_modules/$scope"
          ln -sf "../../$pkg_dir" "node_modules/$scope"
        fi
      fi
    done
    chmod -R u+w packages
    # npm 在 sandbox 中完全无法工作
    # 1. 移除 root package.json 中的 npm 调用，替换为 bun
    sed -i \
      -e 's|npm --prefix packages/lsp-tools-mcp ci && ||g' \
      -e 's|npm --prefix packages/lsp-daemon ci && ||g' \
      -e 's|npm --prefix packages/omo-codex/plugin ci && ||g' \
      -e 's|npm --prefix packages/lsp-tools-mcp run build|bun run --cwd packages/lsp-tools-mcp build|g' \
      -e 's|npm --prefix packages/lsp-daemon run build|bun run --cwd packages/lsp-daemon build|g' \
      package.json
    # 2. 从所有子包 package.json 中移除 tsc 调用（.d.ts 类型声明运行时不需要）
    #    同时移除 ensure-core-links.mjs（只创建开发用符号链接）
    find packages/ -name package.json -exec sed -i \
      -e 's| && tsc -p tsconfig.build.json --emitDeclarationOnly||g' \
      -e 's|tsc -p tsconfig.build.json --emitDeclarationOnly && ||g' \
      -e 's|tsc -p tsconfig.build.json --emitDeclarationOnly||g' \
      -e 's| && tsc -p tsconfig.build.json||g' \
      -e 's|tsc -p tsconfig.build.json && ||g' \
      -e 's|tsc -p tsconfig.build.json||g' \
      -e 's|node scripts/ensure-core-links.mjs && ||g' \
      {} +
    # 移除变空的 build 脚本行（只剩 tsc 的组件），避免 "Script not found" 错误
    find packages/ -name package.json -exec sed -i '/"build"[[:space:]]*:[[:space:]]*""/d' {} +
    # 3. 同时移除 root build 脚本中的 tsc --emitDeclarationOnly
    sed -i 's| && tsc --emitDeclarationOnly||g' package.json
    sed -i 's|tsc --emitDeclarationOnly && ||g' package.json
    # 移除所有 --strict 标志（无 .git 环境下 git submodule 必然失败）
    sed -i 's|--strict||g' package.json packages/omo-codex/plugin/package.json
    # 4. 全面替换所有 .mjs/.js 脚本中的 npm 为 bun（npm 在 sandbox 中完全崩溃）
    #    spawnSync("npm ci") → bun install
    find packages/ -name '*.mjs' -o -name '*.js' | xargs sed -i \
      -e 's|spawnSync("npm", \["ci"\]|spawnSync("bun", ["install", "--no-progress", "--ignore-scripts"]|g' \
      -e 's|spawnSync("npm", \["run", |spawnSync("bun", ["run", |g' \
      -e 's|execSync("npm ci"|execSync("bun install --no-progress --ignore-scripts"|g' \
      -e 's|execSync("npm run |execSync("bun run |g' \
      -e 's|run("npm", \["run", "--workspace", workspace, "build"\], root)|run("bun", ["run", "build"], join(root, workspace))|g' \
      -e 's|run("npm", \["run", "build"\]|run("bun", ["run", "build"]|g' \
      2>/dev/null || true
    # 5. build-bundled-mcp-runtimes.mjs 检查 dist/index.d.ts，但我们跳过了 tsc
    #    移除 .d.ts 要求，避免触发 npm rebuild
    sed -i 's|, "dist/index.d.ts"||g' \
      packages/omo-codex/plugin/scripts/build-bundled-mcp-runtimes.mjs
    # 5b. stage-lsp-daemon-runtime.mjs (v4.19.0 新增) 的 REQUIRED_OUTPUTS 数组包含 .d.ts 文件
    #     我们跳过了 tsc --emitDeclarationOnly，所以这些文件不存在。移除这些行。
    if [ -f packages/omo-senpi/plugin/scripts/stage-lsp-daemon-runtime.mjs ]; then
      sed -i '/"index\.d\.ts",/d; /"client\.d\.ts",/d; /"daemon-client\.d\.ts",/d' \
        packages/omo-senpi/plugin/scripts/stage-lsp-daemon-runtime.mjs
    fi
    # 5c. lsp-daemon 需要 @types/node 才能运行 tsc（devDependency 在 workspace hoisting 下不可见）
    if [ -d packages/lsp-daemon ]; then
      mkdir -p packages/lsp-daemon/node_modules
      ln -sf ../../../node_modules/@types packages/lsp-daemon/node_modules/@types 2>/dev/null || true
      # 上游 bun build 只编译 cli.ts index.ts client.ts，缺少 daemon-client.ts
      # stage-lsp-daemon-runtime.mjs 的 REQUIRED_OUTPUTS 需要 daemon-client.js
      sed -i 's|bun build src/cli.ts src/index.ts src/client.ts --outdir dist|bun build src/cli.ts src/index.ts src/client.ts src/daemon-client.ts --outdir dist|g' \
        packages/lsp-daemon/package.json
    fi
    # 5d. omo-codex/plugin/components/lsp 的 build-runtime.mjs 用 tsc + bun build
    #     tsc 在 sandbox 中因缺少 @types/node 而失败
    #     替换为只用 bun build 的简化版（bun 可以直接编译 TypeScript）
    if [ -f packages/omo-codex/plugin/components/lsp/scripts/build-runtime.mjs ]; then
      cat > packages/omo-codex/plugin/components/lsp/scripts/build-runtime.mjs << 'BUILDRUNTIMEEOF'
#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const SCHEMA_VERSION = 1;
const componentRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const distDir = join(componentRoot, "dist");
const manifestPath = join(distDir, ".omo-runtime-manifest.json");

function sha256File(path) { return createHash("sha256").update(readFileSync(path)).digest("hex"); }
function isRecord(value) { return typeof value === "object" && value !== null && !Array.isArray(value); }
function walk(root) { const entries = []; for (const entry of readdirSync(root, { withFileTypes: true })) { const p = join(root, entry.name); if (entry.isDirectory()) entries.push(...walk(p)); else if (entry.isFile()) entries.push(p); } return entries; }
function packageVersion() { const parsed = JSON.parse(readFileSync(join(componentRoot, "package.json"), "utf8")); return parsed.version; }

if (!existsSync(join(componentRoot, "src"))) { process.exit(0); }

rmSync(distDir, { recursive: true, force: true });
mkdirSync(distDir, { recursive: true });
execSync("bun build src/cli.ts --target node --format esm --outfile dist/cli.js", { cwd: componentRoot, stdio: "inherit" });

const manifest = {
  schemaVersion: SCHEMA_VERSION,
  version: packageVersion(),
  inputDigest: "sha256:" + createHash("sha256").update(readFileSync(join(componentRoot, "package.json"))).digest("hex"),
  outputs: walk(distDir).filter(p => relative(distDir, p) !== ".omo-runtime-manifest.json").map(p => ({ path: relative(distDir, p), sha256: sha256File(p) }))
};
manifest.outputs.sort((a, b) => a.path.localeCompare(b.path));
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
console.log("Built components/lsp runtime: " + distDir);
BUILDRUNTIMEEOF
    fi
    # 6. lsp 组件的 prebuild 钩子调用 build-lsp-daemon.mjs 和 build-lsp-tools.mjs
    #    它们试图 bun install（无网络），改为创建符号链接指向已构建的顶层包
    mkdir -p packages/omo-codex/plugin/components/lsp/node_modules/@code-yeongyu
    ln -sf ../../../../../../lsp-daemon packages/omo-codex/plugin/components/lsp/node_modules/@code-yeongyu/lsp-daemon
    ln -sf ../../../../../../lsp-tools-mcp packages/omo-codex/plugin/components/lsp/node_modules/@code-yeongyu/lsp-tools-mcp
    echo '#!/usr/bin/env node' > packages/omo-codex/plugin/components/lsp/scripts/build-lsp-daemon.mjs
    echo 'console.log("lsp-daemon already built at top level, skipping");' >> packages/omo-codex/plugin/components/lsp/scripts/build-lsp-daemon.mjs
    echo '#!/usr/bin/env node' > packages/omo-codex/plugin/components/lsp/scripts/build-lsp-tools.mjs
    echo 'console.log("lsp-tools already built at top level, skipping");' >> packages/omo-codex/plugin/components/lsp/scripts/build-lsp-tools.mjs
    # 7. bootstrap 组件用 "bun x esbuild" 下载 esbuild（无网络），改为用 bun build（其他组件均用 bun build）
    cat > packages/omo-codex/plugin/components/bootstrap/scripts/build.mjs << 'BOOTSTRAP_EOF'
#!/usr/bin/env node
import { execSync } from "node:child_process";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const componentRoot = dirname(dirname(fileURLToPath(import.meta.url)));
console.log("Bundling bootstrap with bun build...");
execSync("bun build src/cli.ts --target node --format esm --outfile dist/cli.js", {
  cwd: componentRoot,
  stdio: "inherit",
});
console.log("Bootstrap bundle done");
BOOTSTRAP_EOF
  '';

  buildPhase = ''
    runHook preBuild
    bun run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib
    cp -r dist $out/
    cp package.json $out/
    cp -r .opencode $out/ 2>/dev/null || true

    makeWrapper ${lib.getExe pkgs.bun} $out/bin/oh-my-opencode \
      --prefix PATH : ${lib.makeBinPath [ pkgs.bun ]} \
      --add-flags "run --prefer-offline --no-install --cwd $out $out/dist/cli/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Batteries-Included OpenCode Plugin with Multi-Model Orchestration";
    homepage = "https://github.com/code-yeongyu/oh-my-openagent";
    license = licenses.unfree;
    mainProgram = "oh-my-opencode";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
