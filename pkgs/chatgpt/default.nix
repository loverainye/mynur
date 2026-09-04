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
  version = "26.901.31953";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    hash = "sha256-K7RSK+h33mwX5fTAcbBuxkiCsd0JqPC9IErwI6t1bZw=";
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

  # autoPatchelf moves PT_INTERP beyond detect-libc's 2 KiB scan. Its
  # process.report fallback trips Electron's CFI, so use the glibc watcher.
  # Keep the replacement the same length to preserve app.asar offsets.
  postPatch = ''
    sed -i "s|const family = familySync();|const family = 'glibc'     ;|" \
      usr/lib/chatgpt/resources/app.asar
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
    while IFS= read -r -d $'\0' native \
      && IFS= read -r -d $'\0' description; do
      case "$description" in
        *"ELF 64-bit LSB"*"x86-64"*)
          case "$description" in
            *musl*) rm -f "$native" ;;
          esac
          ;;
        *ELF*) rm -f "$native" ;;
      esac
    done < <(
      find "$out/lib/chatgpt" -type f \( \
        -perm /111 \
        -o -iname '*.node' \
        -o -iname '*.so' \
        -o -iname '*.so.*' \
      \) -print0 | xargs -0 -r file -0 -0 --
    )

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
