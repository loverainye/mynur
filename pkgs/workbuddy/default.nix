{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  dpkg,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  gcc,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libpulseaudio,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  udev,
  wayland,
  xdg-utils,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "workbuddy";
  version = "5.6.2.40046327";

  src = fetchurl {
    url = "https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/WorkBuddy-linux-x64-deb-5.6.2.40046327-c7b525f3.deb";
    # The endpoint reports f6451117..., while the current CDN object verifies as c5db5f26....
    hash = "sha256-EhSa2MDNdI/VBi2PYseCfWiNgJVCetqZsa6ecBmJdSM=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    gcc.cc.lib
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libpulseaudio
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    mesa
    nspr
    nss
    pango
    systemd
    udev
    wayland
    zlib
  ];

  dontStrip = true;

  # Preserve the program-header order of the bundled Node executable.
  patchelfFlags = [ "--no-sort" ];

  # These are bundled for other libc/OS targets and are not loaded on Linux.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc++.so.9.0"
    "libc++abi.so.6.0"
    "libpthread.so.26.1"
    "libm.so.10.1"
  ];

  # libGL is supplied through the launcher below. Injecting it into every
  # executable's RPATH makes patchelf abort on the BOLT-optimized Python.
  runtimeDependencies = [];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/workbuddy"
    cp -r opt/WorkBuddy/. "$out/lib/workbuddy/"

    mkdir -p "$out/bin"
    makeWrapper "$out/lib/workbuddy/workbuddy" "$out/bin/workbuddy" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd ]}

    install -Dm644 usr/share/applications/workbuddy.desktop \
      "$out/share/applications/workbuddy.desktop"
    sed -i 's|^Exec=/opt/WorkBuddy/workbuddy|Exec=workbuddy|' \
      "$out/share/applications/workbuddy.desktop"

    cp -r usr/share/icons "$out/share/"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    bash -n "$out/bin/workbuddy"
    "$out/lib/workbuddy/resources/runtime/node/bin/node" --version
    "$out/lib/workbuddy/resources/runtime/python/bin/python3.13" -I -B -c \
      'import ctypes, ssl, sqlite3, venv, zlib; print(ssl.OPENSSL_VERSION); print(sqlite3.sqlite_version)'
    ELECTRON_RUN_AS_NODE=1 "$out/bin/workbuddy" -e 'console.log(process.versions.electron)'
    runHook postInstallCheck
  '';

  meta = {
    description = "WorkBuddy Desktop - Tencent AI Agent Desktop Application";
    homepage = "https://copilot.tencent.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "workbuddy";
  };
}
