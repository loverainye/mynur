{ lib
, python3Packages
, fetchFromGitHub
, ...
}:

python3Packages.buildPythonApplication rec {
  pname = "graphify";
  version = "0.9.16";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "safishamsi";
    repo = "graphify";
    rev = "v${version}";
    hash = "sha256-1zujI03y4JQ2xUpihYsXEVLFiYy7rU7pua4zvSxltWg=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  nativeBuildInputs = with python3Packages; [
    pythonRelaxDepsHook
  ];

  # 放宽 tree-sitter 等依赖的版本约束,适配 nixpkgs 当前版本
  pythonRelaxDeps = [
    "tree-sitter"
    "tree-sitter-python"
    "tree-sitter-javascript"
    "tree-sitter-rust"
    "tree-sitter-c-sharp"
    "tree-sitter-bash"
    "tree-sitter-json"
    "tree-sitter-sql"
  ];

  propagatedBuildInputs = with python3Packages; [
    # 核心
    networkx
    datasketch
    rapidfuzz

    # tree-sitter 本体 + nixpkgs 中已有的语言包
    tree-sitter
    tree-sitter-python
    tree-sitter-javascript
    tree-sitter-rust
    tree-sitter-c-sharp
    tree-sitter-bash
    tree-sitter-json
    tree-sitter-sql

    # extras: mcp
    mcp

    # extras: pdf
    pypdf
    markdownify

    # extras: office
    python-docx
    openpyxl

    # extras: watch
    watchdog

    # extras: leiden (社区聚类算法)
    # graspologic — 暂时禁用: 其传递依赖 future-1.0.0 不兼容 python3.13
    # 待上游修复或 nixpkgs 更新后重新启用
  ];

  # 以下 tree-sitter 语言包在 nixpkgs 中暂无 python3Packages 绑定,
  # 有需要时可自行添加或 upstream 至 nixpkgs:
  # tree-sitter-typescript tree-sitter-go tree-sitter-java
  # tree-sitter-c tree-sitter-cpp tree-sitter-ruby tree-sitter-kotlin
  # tree-sitter-scala tree-sitter-php tree-sitter-swift tree-sitter-lua
  # tree-sitter-zig tree-sitter-powershell tree-sitter-elixir
  # tree-sitter-objc tree-sitter-julia tree-sitter-verilog
  # tree-sitter-fortran tree-sitter-dm tree-sitter-groovy

  doCheck = false;

  meta = {
    description = "Turn any folder of code, docs, papers, images, or videos into a queryable knowledge graph";
    homepage = "https://github.com/safishamsi/graphify";
    license = lib.licenses.mit;
    mainProgram = "graphify";
    platforms = lib.platforms.linux;
  };
}
