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
  version = "5.5.3.37748631";

  src = fetchurl {
    url = "https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/WorkBuddy-linux-x64-deb-5.5.3.37748631-104760a2.deb";
    # The endpoint reports f6451117..., while the current CDN object verifies as c5db5f26....
    hash = "sha256-xdtfJpVhgiybCsFokec7kAVtrEoTQ2lwADberpJ3sGI=";
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

  # These are bundled for other libc/OS targets and are not loaded on Linux.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc++.so.9.0"
    "libc++abi.so.6.0"
    "libpthread.so.26.1"
    "libm.so.10.1"
  ];

  # Electron loads libGL through dlopen rather than a DT_NEEDED entry.
  runtimeDependencies = [ libglvnd ];

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

  meta = {
    description = "WorkBuddy Desktop - Tencent AI Agent Desktop Application";
    homepage = "https://copilot.tencent.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "workbuddy";
  };
}
