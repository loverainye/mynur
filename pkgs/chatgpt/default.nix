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
  tpm2-tss,
  udev,
  xdg-utils,
}:

stdenv.mkDerivation rec {
  pname = "chatgpt";
  version = "26.1023.50603";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    hash = "sha256-9cm/Lwo9UME5F69hGFp5H1IOWDmQn+qCLYhr41sSGyY=";
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
    tpm2-tss
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

    # Filter actual native objects, not platform names in paths. The CUA
    # entry points statically import cross-platform JavaScript, including
    # bind_windows_app.js and Linux's list_windows.js.
    while IFS= read -r -d $'\0' native \
      && IFS= read -r -d $'\0' description; do
      case "$description" in
        *"ELF 64-bit LSB"*"x86-64"*)
          case "$native $description" in
            *musl*) rm -f "$native" ;;
          esac
          ;;
        *ELF*|*PE32*|*MS-DOS\ executable*|*Mach-O*) rm -f "$native" ;;
      esac
    done < <(
      find "$out/lib/chatgpt" -type f -print0 | xargs -0 -r file -0 -0 --
    )

    chmod 755 "$out/lib/chatgpt/ChatGPT" "$out/lib/chatgpt/codex-launcher"

    mkdir -p "$out/bin"
    makeWrapper "$out/lib/chatgpt/codex-launcher" "$out/bin/chatgpt" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}:$out/lib/chatgpt"

    mkdir -p "$out/share"
    cp -r usr/share/. "$out/share/"
    sed -i -E 's|^Exec=.*$|Exec=chatgpt %U|' "$out/share/applications/chatgpt.desktop"
  '';

  # The browser-control plugin copies files from the application bundle and
  # then modifies them. Nix store files are always read-only, so launch from
  # a user-writable copy of the bundle to let plugin/bootstrap registration
  # create browser-service.mjs and the native-messaging manifest.
  postFixup = ''
    mv "$out/bin/chatgpt" "$out/bin/chatgpt-store"
    cat > "$out/bin/chatgpt" <<'CHATGPT_WRAPPER'
    #!${stdenv.shell}
    set -euo pipefail

    data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
    runtime_root="$data_home/chatgpt/nix-runtime-${version}"
    runtime_app="$runtime_root/chatgpt"
    if [ ! -x "$runtime_app/codex-launcher" ] \
      || [ ! -x "$runtime_app/ChatGPT" ] \
      || [ ! -x "$runtime_app/browser_crashpad_handler" ] \
      || [ "$(cat "$runtime_app/.nix-store-path" 2>/dev/null || true)" != '@STORE_APP@' ]; then
      mkdir -p "$runtime_root"
      temporary="$runtime_root/.chatgpt-$$"
      rm -rf "$temporary"
      # Keep executable bits from the bundle while making files user-owned.
      cp -a --no-preserve=ownership "@STORE_APP@" "$temporary"
      chmod -R u+rwX "$temporary"
      printf '%s\n' '@STORE_APP@' > "$temporary/.nix-store-path"
      rm -rf "$runtime_app"
      mv "$temporary" "$runtime_app"
    fi

    exec "$runtime_app/codex-launcher" "$@"
    CHATGPT_WRAPPER
    sed -i "s|@STORE_APP@|$out/lib/chatgpt|" "$out/bin/chatgpt"
    chmod 755 "$out/bin/chatgpt"
  '';

  preFixup = ''
    # patchelf's program-header sorting breaks the bundled Node executable.
    # Keep it out of normal fixups and patch it once without sorting, last.
    mv "$out/lib/chatgpt/resources/cua_node/bin/node" "$NIX_BUILD_TOP/chatgpt-cua-node"
    patchChatgptCuaNode() {
      mv "$NIX_BUILD_TOP/chatgpt-cua-node" "$out/lib/chatgpt/resources/cua_node/bin/node"
      patchelf --no-sort \
        --set-interpreter "${stdenv.cc.libc}/lib/ld-linux-x86-64.so.2" \
        --set-rpath "${lib.makeLibraryPath [ gcc.cc.lib ]}" \
        "$out/lib/chatgpt/resources/cua_node/bin/node"
    }
    postFixupHooks+=(patchChatgptCuaNode)
  '';

  # Catch missing transitive CUA imports before publishing a broken package.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    bash -n "$out/bin/chatgpt"
    "$out/lib/chatgpt/resources/cua_node/bin/node" --input-type=module -e '
      import { pathToFileURL } from "node:url";
      const root = process.argv[1];
      for (const entry of [
        "lib/js/oai_js_cua/src/tinysky_alt/create_tinysky_alt.js",
        "project/cua/sky_js/src/create_client.js",
      ]) {
        await import(pathToFileURL(root + "/" + entry).href);
      }
    ' "$out/lib/chatgpt/resources/cua_node/lib/node_modules/@oai/cua/dist"
    runHook postInstallCheck
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
