{ stdenv
, fetchurl
, unzip
, autoPatchelfHook
, unixodbc
, gcc
}:

stdenv.mkDerivation {
  pname = "duckdb-odbc";
  version = "1.5.5.0";

  src = fetchurl {
    url = "https://github.com/duckdb/duckdb-odbc/releases/download/v1.5.5.0/duckdb_odbc-linux-amd64.zip";
    sha256 = "sha256-shEmM/TtuEUU6VyJkn/DwyxGVaw22yJC90c7f7kPg2Q=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  buildInputs = [
    unixodbc
    gcc.cc.lib
    stdenv.cc.cc.lib
  ];

  # 自动修复二进制依赖
  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
      runHook preUnpack
      unzip $src
      runHook postUnpack
    '';

  installPhase = ''
    runHook preInstall

    # 创建输出目录
    mkdir -p $out/lib

    # 复制库文件到标准位置
    cp libduckdb_odbc.so $out/lib/
    runHook postInstall
  '';

  # 自动修复库依赖
  autoPatchelfIgnoreMissingDeps = true;
}
