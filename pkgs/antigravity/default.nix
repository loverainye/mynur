{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  makeDesktopItem,
  copyDesktopItems,
}:

let
  version = "2.1.4";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-6481382726303744/linux-x64/Antigravity.tar.gz";
    sha256 = "sha256-T/sDKgQQ0i/lDL32bXL1vXi+vvBYIp3AUktL3waaZZo=";
  };

  antigravity = stdenv.mkDerivation {
    pname = "antigravity";
    inherit version src;

    sourceRoot = "Antigravity-x64";

    nativeBuildInputs = [
      copyDesktopItems
    ];

    dontBuild = true;
    dontConfigure = true;
    dontAutoPatchelf = true;
    stripExclude = [ "antigravity" ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity $out/bin

      # Install all files from the tarball
      cp -r ./* $out/lib/antigravity/

      # Link binary
      ln -s $out/lib/antigravity/antigravity $out/bin/antigravity

      runHook postInstall
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "antigravity";
        desktopName = "Antigravity";
        comment = "Agentic development platform";
        genericName = "Text Editor";
        exec = "antigravity %F";
        icon = "antigravity";
        startupNotify = true;
        startupWMClass = "Antigravity";
        categories = [ "Utility" "TextEditor" "Development" "IDE" ];
        keywords = [ "vscode" ];
        mimeTypes = [ "x-scheme-handler/antigravity" ];
      })
    ];

    meta = {
      mainProgram = "antigravity";
      description = "Agentic development platform, evolving the IDE into the agent-first era";
      homepage = "https://antigravity.google";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

in
buildFHSEnv {
  pname = "antigravity";
  inherit version;

  targetPkgs = pkgs: [
    pkgs.glibc
    pkgs.curl
    pkgs.icu
    pkgs.libunwind
    pkgs.libuuid
    pkgs.lttng-ust
    pkgs.openssl
    pkgs.zlib
    pkgs.krb5
    pkgs.glib
    pkgs.nspr
    pkgs.nss
    pkgs.dbus
    pkgs.at-spi2-atk
    pkgs.cups
    pkgs.expat
    pkgs.libxkbcommon
    pkgs.libx11
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxcb
    pkgs.libxext
    pkgs.libxfixes
    pkgs.libxrandr
    pkgs.cairo
    pkgs.pango
    pkgs.alsa-lib
    pkgs.libgbm
    pkgs.udev
    pkgs.libudev0-shim
    pkgs.fontconfig
    pkgs.libdbusmenu
    pkgs.wayland
    pkgs.libsecret
    pkgs.webkitgtk_4_1
    pkgs.libxkbfile
    pkgs.gtk3
  ];

  extraBwrapArgs = [
    "--bind-try /etc/nixos/ /etc/nixos/"
    "--ro-bind-try /etc/xdg/ /etc/xdg/"
  ];

  extraInstallCommands = ''
    ln -s "${antigravity}/share" "$out/"
  '';

  runScript = "${antigravity}/bin/antigravity";

  dieWithParent = false;

  meta = antigravity.meta // {
    description = "Wrapped variant of antigravity which launches in a FHS compatible environment, should allow for easy usage of extensions without nix-specific modifications";
  };
}
