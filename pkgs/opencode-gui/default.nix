# opencode-desktop: AI-powered code editor
# Electron 应用，使用共享的 X11/GUI 运行时依赖
{ stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, lib
, libglvnd
, alsa-lib
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libdrm
, libnotify
, libsecret
, libx11
, libxcb
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxkbcommon
, libxrandr
, libxrender
, libxscrnsaver
, libxtst
, mesa
, nspr
, nss
, pango
, xdg-utils
}:

stdenv.mkDerivation rec {
  pname = "opencode-desktop";
  version = "1.18.4";

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-desktop-linux-amd64.deb";
    sha256 = "sha256-pnvEepje0QJ156jzL6PhZIC1WZbNUiMtqRRQQytNZZk=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  # 共享的 Electron 运行时依赖
  buildInputs = [
    alsa-lib at-spi2-atk at-spi2-core cairo cups dbus expat
    fontconfig freetype gdk-pixbuf glib gtk3 libdrm libglvnd
    libnotify libsecret libx11 libxcb libxcomposite libxcursor
    libxdamage libxext libxfixes libxi libxkbcommon libxrandr
    libxrender libxscrnsaver libxtst mesa nspr nss pango xdg-utils
  ];

  unpackPhase = ''
    ar x "$src"
    tar xf data.tar.xz
  '';

  installPhase = ''
    # Install binary and resources
    mkdir -p $out/opt/OpenCode
    cp -r opt/OpenCode/. $out/opt/OpenCode/

    # Remove musl node modules (not needed on glibc Linux)
    rm -rf $out/opt/OpenCode/resources/app.asar.unpacked/node_modules/@parcel/watcher-linux-x64-musl
    rm -rf $out/opt/OpenCode/resources/app.asar.unpacked/node_modules/@msgpackr-extract/msgpackr-extract-linux-x64/node.napi.musl.node
    rm -rf $out/opt/OpenCode/resources/app.asar.unpacked/node_modules/@msgpackr-extract/msgpackr-extract-linux-x64/node.abi115.musl.node

    # Ensure binary is executable (deb extraction may lose +x)
    chmod +x $out/opt/OpenCode/ai.opencode.desktop

    # Create bin wrapper
    mkdir -p $out/bin
    makeWrapper $out/opt/OpenCode/ai.opencode.desktop $out/bin/opencode-desktop \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --add-flags "--no-sandbox"

    # Install desktop file and icons
    mkdir -p $out/share
    cp -r usr/share/. $out/share/ 2>/dev/null || true

    # Fix desktop file Exec paths — point to wrapped binary
    for f in "$out/share/applications/"*.desktop; do
      [ -f "$f" ] && sed -i 's|Exec=/opt/OpenCode/ai.opencode.desktop|Exec=opencode-desktop|' "$f"
    done
  '';

  meta = {
    description = "OpenCode Desktop - AI-powered code editor";
    homepage = "https://opencode.ai/";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "opencode-desktop";
  };
}
