{ lib, stdenv, fetchurl, autoPatchelfHook, buildFHSEnv, gtk3, webkitgtk_4_1
, glib, glibc, gcc, coreutils, bash, iproute2, iptables, util-linux, procps
, kmod, systemd, polkit, cacert, gnutar, gzip, xz, zstd }:
let
  version = "0.2.0";
  payload = stdenv.mkDerivation {
    pname = "kiri-unwrapped";
    inherit version;
    src = fetchurl {
      url = "https://github.com/libracoder/kiri/releases/download/v${version}/kiri_${version}_amd64.deb";
      hash = "sha256-ezaLxvoMsK6fM+Q3ggGAPt51sPaL1YwHxlQmLFPRZrU=";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ gtk3 webkitgtk_4_1 gcc.cc.lib ];
    unpackPhase = ''
      ar x "$src"
      tar xf data.tar.*
    '';
    installPhase = ''
      mkdir -p "$out"
      cp -r usr/. "$out/"
      mkdir -p "$out/lib/systemd/system"
      cp lib/systemd/system/kiri.service "$out/lib/systemd/system/"
    '';
    dontStrip = true;
  };
in
(buildFHSEnv {
  name = "kiri";
  targetPkgs = _: [ payload gtk3 webkitgtk_4_1 glib glibc gcc.cc.lib
    coreutils bash iproute2 iptables util-linux procps kmod systemd polkit
    cacert gnutar gzip xz zstd ];
  runScript = "${payload}/bin/kiri";
  extraInstallCommands = ''
    mkdir -p "$out/share"
    cp -r ${payload}/share/applications ${payload}/share/icons "$out/share/"
    chmod -R u+w "$out/share"
    substituteInPlace "$out/share/applications/kiri.desktop" \
      --replace-fail 'Exec=/usr/lib/kiri/kiri-window ui' "Exec=$out/bin/kiri ui" \
      --replace-fail 'Icon=/usr/share/icons/hicolor/scalable/apps/kiri.svg' 'Icon=kiri'
  '';
  meta = {
    description = "Lightweight container runtime with Docker API and native GUI";
    homepage = "https://github.com/libracoder/kiri";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "kiri";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}).overrideAttrs (old: {
  inherit version;
  passthru = (old.passthru or {}) // { unwrapped = payload; };
})
