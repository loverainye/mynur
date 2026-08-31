{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  gettext,
  fcitx5,
  makeBinaryWrapper,
  qt6,
  autoPatchelfHook,
  systemdLibs,
  curl,
  libarchive,
  openssl,
  pipewire,
  onnxruntime,
  cli11,
  sherpa-onnx,
  nlohmann_json,
  clang,
  mold,
  python3,
  libopus,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fcitx5-vinput";
  version = "2.3.8";

  src = fetchFromGitHub {
    owner = "xifan2333";
    repo = "fcitx5-vinput";
    tag = "v${finalAttrs.version}";
    hash = "sha256-VBUeaahlhMrfaJCAHJdRjImYcQ4OmgUrFA1JsS3vu8Y=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    gettext
    fcitx5
    makeBinaryWrapper
    qt6.wrapQtAppsHook
    autoPatchelfHook
  ];

  buildInputs = [
    fcitx5
    systemdLibs
    curl
    libarchive
    openssl
    pipewire
    onnxruntime
    qt6.qtbase
    cli11
    sherpa-onnx
    nlohmann_json
    clang
    mold
  ];

  cmakeFlags = [
    "-DVINPUT_FETCH_CLI11=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_C_COMPILER=clang"
    "-DCMAKE_CXX_COMPILER=clang++"
    "-DCMAKE_LINKER=mold"
    "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold"
    "-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold"
  ];

  postInstall = ''
    rm -f "$out/lib/fcitx5-vinput/libonnxruntime.so"

    for program in "$out"/bin/*; do
      wrapProgram "$program" \
        --prefix PATH : ${lib.makeBinPath [ python3 ]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libopus ]}
    done
  '';

  meta = {
    description = "Offline voice input addon for Fcitx5";
    homepage = "https://github.com/xifan2333/fcitx5-vinput";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ ];
    mainProgram = "vinput-gui";
  };
})
