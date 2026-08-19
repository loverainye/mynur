{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  dpkg,
  file,
  alsa-lib,
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
  graphite2,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libpulseaudio,
  libusb1,
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
  qt5,
  qt6,
  systemd,
  udev,
  xdg-utils,
}:

stdenv.mkDerivation rec {
  pname = "chatgpt";
  version = "26.814.41957";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    hash = "sha256-R3iyanq9CGRyFNWwXBe9Pr4tlojRRtq/AXwaL6+TrH0=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    file
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
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
    graphite2
    gtk3
    libdrm
    libgbm
    libglvnd
    libpulseaudio
    libusb1
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
    qt5.qtbase.out
    qt6.qtbase.out
    systemd
    udev
    xdg-utils
  ];

  unpackPhase = ''
    dpkg -x "$src" .
  '';

  installPhase = ''
    mkdir -p "$out/lib/chatgpt"
    cp -r usr/lib/chatgpt/. "$out/lib/chatgpt/"

    # The package ships native modules for other operating systems, libc
    # implementations, and CPU architectures. Keep only Linux glibc x86_64
    # modules so autoPatchelfHook sees valid native objects only.
    find "$out/lib/chatgpt" -type d \( \
      -iname '*darwin*' \
      -o -iname '*windows*' \
      -o -iname '*win32*' \
      -o -iname '*freebsd*' \
      -o -iname '*openbsd*' \
      -o -iname '*android*' \
      -o -iname '*musl*' \
      -o -iname '*arm64*' \
      -o -iname '*aarch64*' \
      -o -iname '*armv7*' \
      -o -iname '*ia32*' \
      -o -iname '*x86_64*' ! -iname '*linux*' \
    \) -prune -exec rm -rf {} +
    find "$out/lib/chatgpt" -type f \( \
      -iname '*.exe' \
      -o -iname '*.dll' \
      -o -iname '*.dylib' \
      -o -iname '*darwin*' \
      -o -iname '*windows*' \
      -o -iname '*musl*' \
      -o -iname '*arm64*' \
      -o -iname '*aarch64*' \
      -o -iname '*armv7*' \
      -o -iname '*ia32*' \
    \) -delete
    while IFS= read -r -d $'\0' native; do
      description=$(file -b "$native")
      case "$description" in
        *"ELF 64-bit LSB"*"x86-64"*)
          case "$description" in
            *musl*) rm -f "$native" ;;
          esac
          ;;
        *ELF*) rm -f "$native" ;;
      esac
    done < <(find "$out/lib/chatgpt" -type f -print0)

    chmod 755 "$out/lib/chatgpt/ChatGPT" "$out/lib/chatgpt/codex-launcher"

    mkdir -p "$out/bin"
    makeWrapper "$out/lib/chatgpt/codex-launcher" "$out/bin/chatgpt" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}:$out/lib/chatgpt"

    mkdir -p "$out/share"
    cp -r usr/share/. "$out/share/"
    sed -i -E 's|^Exec=.*$|Exec=chatgpt %U|' "$out/share/applications/chatgpt.desktop"
  '';

  meta = {
    description = "Official ChatGPT desktop application for Linux";
    homepage = "https://chatgpt.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "chatgpt";
  };
}
