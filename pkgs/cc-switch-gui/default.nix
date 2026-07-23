{ stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, openssl
, gtk3
, webkitgtk_4_1
, libsoup_3
, glib
, pango
, cairo
, gdk-pixbuf
, mesa
, libx11
, cups
, expat
, libayatana-appindicator
}:

stdenv.mkDerivation rec {
  pname = "cc-switch";
  version = "3.17.0";

  src = fetchurl {
    url = "https://github.com/farion1231/cc-switch/releases/download/v${version}/CC-Switch-v${version}-Linux-x86_64.deb";
    sha256 = "sha256-HUV1MsW8Of0BibR8FZ59S1lsMkTOs4vcibH2zcn1Hno=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    openssl
    gtk3
    webkitgtk_4_1
    libsoup_3
    glib
    pango
    cairo
    gdk-pixbuf
    mesa
    libx11
    cups
    expat
    libayatana-appindicator
  ];

  unpackPhase = ''
    ar x ${src}
    tar xf data.tar.xz || tar xf data.tar.gz || tar xf data.tar.zst
  '';

  installPhase = ''
    # Install binary
    mkdir -p $out/bin
    cp -r usr/bin/cc-switch $out/bin/

    # Install resources
    mkdir -p $out/share
    cp -r usr/share/* $out/share/
    
    # Fix the desktop file
    if [ -f "$out/share/applications/CC Switch.desktop" ]; then
      sed -i "s|Exec=.*|Exec=cc-switch|" "$out/share/applications/CC Switch.desktop"
    fi

    # Wrap binary to provide dynamically loaded libraries and force X11 backend for Wayland titlebar fix
    wrapProgram $out/bin/cc-switch \
      --prefix LD_LIBRARY_PATH : "${libayatana-appindicator}/lib" \
      --set GDK_BACKEND x11
  '';

}
