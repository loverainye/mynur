# 通用二进制包构建函数
# 用于 opencode-cli、mimode-cli、kilo-cli、cc-switch-cli 等预编译二进制包
#
# 用法:
#   { stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:
#   import ./lib/binary.nix { inherit stdenv lib fetchurl autoPatchelfHook glibc makeWrapper; } {
#     pname = "my-package";
#     version = "1.0.0";
#     url = "https://example.com/pkg.tar.gz";
#     hash = "sha256-...";
#   }
{ stdenv, lib, fetchurl, autoPatchelfHook, glibc, makeWrapper }:

# 返回一个函数，接受包特定的参数
{ pname
, version
, url
, hash
, binaryName ? pname
, binName ? pname
, extraFiles ? ""
, extraInstall ? ""
, usePatchelf ? true
, customWrapper ? null
, meta ? {}
}:

stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl { inherit url hash; };

  nativeBuildInputs = lib.optionals usePatchelf [ autoPatchelfHook ]
    ++ lib.optionals (customWrapper == null) [ makeWrapper ];

  buildInputs = lib.optionals usePatchelf [ glibc ];

  unpackPhase = "tar xzf $src";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/${pname}
    cp ${binaryName} $out/share/${pname}/
    chmod +x $out/share/${pname}/${binaryName}
    ${extraFiles}
    ${if customWrapper != null then ''
      cat > $out/bin/${binName} << 'WRAPPER'
${customWrapper}
WRAPPER
      chmod +x $out/bin/${binName}
    '' else ''
      makeWrapper $out/share/${pname}/${binaryName} $out/bin/${binName}
    ''}
    ${extraInstall}
    runHook postInstall
  '';

  meta = {
    description = meta.description or "${pname} binary package";
    homepage = meta.homepage or "";
    license = meta.license or lib.licenses.unfree;
    platforms = meta.platforms or [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = meta.mainProgram or binName;
  } // meta;
}
