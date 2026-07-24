{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  # X11 / GUI runtime deps
  libx11,
  libxrandr,
  libxi,
  libice,
  libsm,
  libxcursor,
  libxext,
  libxkbcommon,
  libxcb,
  # GTK / accessibility
  gtk3,
  atk,
  at-spi2-atk,
  at-spi2-core,
  pango,
  cairo,
  mesa,
  gdk-pixbuf,
  # Audio
  alsa-lib,
  # System
  nss,
  nspr,
  cups,
  expat,
  dbus,
  fontconfig,
  freetype,
  # Desktop
  xdg-utils,
  nix-update-script,
}:

stdenv.mkDerivation rec {
  pname = "v2rayn";
  version = "7.23.4";

  src = fetchurl {
    url = "https://github.com/2dust/v2rayN/releases/download/${version}/v2rayN-linux-64.zip";
    sha256 = "sha256-2MvABBWE34ppKA8tNXm5GT6X6VJ221a192kMwa6Vqp8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    unzip
  ];

  buildInputs = [
    stdenv.cc.cc
    nss
    nspr
    cups
    expat
    dbus
    fontconfig
    freetype
    gtk3
    atk
    at-spi2-atk
    at-spi2-core
    pango
    cairo
    mesa
    gdk-pixbuf
    alsa-lib
    libxkbcommon
    libxcb
  ];

  runtimeDeps = [
    libx11
    libxrandr
    libxi
    libice
    libsm
    libxcursor
    libxext
  ];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/v2rayn $out/bin

    # Copy all files from extracted directory
    cp -r v2rayN/* $out/share/v2rayn/
    chmod +x $out/share/v2rayN/v2rayN

    # Create wrapper
    makeWrapper $out/share/v2rayN/v2rayN $out/bin/v2rayN \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDeps}"

    # Install desktop file
    mkdir -p $out/share/applications
    cat > $out/share/applications/v2rayn.desktop << EOF
[Desktop Entry]
Name=v2rayN
Exec=v2rayN
Icon=v2rayn
Type=Application
Categories=Network;Application;
Terminal=false
Comment=A GUI client for Windows and Linux, support Xray core and sing-box-core and others
EOF

    # Install icon
    if [ -f v2rayN/v2rayN.png ]; then
      install -Dm644 v2rayN/v2rayN.png $out/share/pixmaps/v2rayn.png
    fi

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "v2rayn";
      exec = "v2rayN";
      icon = "v2rayn";
      genericName = "v2rayN";
      desktopName = "v2rayN";
      categories = [
        "Network"
        "Application"
      ];
      terminal = false;
      comment = "A GUI client for Windows and Linux, support Xray core and sing-box-core and others";
    })
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "GUI client for Windows and Linux, support Xray core and sing-box-core and others";
    homepage = "https://github.com/2dust/v2rayN";
    mainProgram = "v2rayN";
    license = with lib.licenses; [ gpl3Plus ];
    maintainers = lib.maintainers;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
