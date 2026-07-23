{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  dpkg,
  # runtime deps
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libpulseaudio,
  libxkbcommon,
  pango,
  udev,
  libX11,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libxcb,
  xdg-user-dirs,
  pipewire,
  libva,
  libvdpau,
  mesa,
  addDriverRunpath,
  patchelf,
  gst_all_1,
  pam,
  libayatana-appindicator,
}:

let
  pname = "rustdesk";
  version = "1.4.9";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.deb";
      hash = "sha256-ckS6R8QOgEFyBEv75llGfFTORlVMmOeMjAQG8dYS/aM=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-aarch64.deb";
      hash = "sha256-zmLJlvFNM/O746Mw6VNkSkS6zn8FiFp5U/c5XWn7ScA=";
    };
  };

  libraries = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libpulseaudio
    libxkbcommon
    pango
    udev
    libX11
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libxcb
    pipewire
    libva
    libvdpau
    mesa
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    pam
    libayatana-appindicator
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  src = srcs.${stdenv.hostPlatform.system} or (throw "rustdesk: unsupported platform ${stdenv.hostPlatform.system}");

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    dpkg
    patchelf
    addDriverRunpath
  ];

  buildInputs = libraries;

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # 主程序及其 flutter data/lib 全部放到 $out/share/rustdesk
    mkdir -p $out/share/rustdesk
    cp -r usr/share/rustdesk/. $out/share/rustdesk/

    # 创建 bin 启动脚本（主程序需要在自身目录下运行，否则找不到 flutter assets）
    mkdir -p $out/bin
    cat > $out/bin/rustdesk << 'EOF'
#!/bin/sh
exec "$out/share/rustdesk/rustdesk" "$@"
EOF
    substituteInPlace $out/bin/rustdesk --replace '$out' "$out"
    chmod +x $out/bin/rustdesk

    # icons
    install -Dm644 usr/share/icons/hicolor/256x256/apps/rustdesk.png \
      $out/share/icons/hicolor/256x256/apps/rustdesk.png
    if [ -f usr/share/icons/hicolor/scalable/apps/rustdesk.svg ]; then
      install -Dm644 usr/share/icons/hicolor/scalable/apps/rustdesk.svg \
        $out/share/icons/hicolor/scalable/apps/rustdesk.svg
    fi

    # polkit actions
    if [ -d usr/share/polkit-1/actions ]; then
      mkdir -p $out/share/polkit-1
      cp -r usr/share/polkit-1/actions $out/share/polkit-1/
    fi

    runHook postInstall
  '';

  preFixup = ''
    myCustomFixup() {
      echo "=== START CUSTOM FIXUP (RUNNING AFTER AUTO-PATCHELF) ==="
      # libayatana-appindicator 通过 dlopen() 动态加载，绕过 RPATH 的一切复杂性：
      # 直接软链到 bundled lib 目录，dlopen 通过已有的 RPATH 就能找到
      for sofile in ${lib.getLib libayatana-appindicator}/lib/libayatana-appindicator*.so*; do
        echo "Linking appindicator sofile: $sofile"
        ln -sf "$sofile" "$out/share/rustdesk/lib/$(basename $sofile)"
      done

      # 追加所有依赖库的路径到主要的 ELF RPATH，确保在 sudo 剥离 LD_LIBRARY_PATH 下 dlopen（如 pipewire, pulseaudio 等）依然能够成功
      # 同时避免触碰 libapp.so 等 Dart 编译出的 AOT 代码以防止其损坏
      echo "Running patchelf --add-rpath..."
      patchelf --add-rpath "${lib.makeLibraryPath (libraries ++ [ libayatana-appindicator ])}:$out/share/rustdesk/lib" $out/share/rustdesk/rustdesk
      patchelf --add-rpath "${lib.makeLibraryPath (libraries ++ [ libayatana-appindicator ])}:$out/share/rustdesk/lib" $out/share/rustdesk/lib/librustdesk.so

      # 为 rustdesk 和 librustdesk.so 添加驱动的 RUNPATH，解决 libcuda.so.1 等 GPU 驱动库加载问题
      echo "Running addDriverRunpath..."
      addDriverRunpath $out/share/rustdesk/rustdesk
      addDriverRunpath $out/share/rustdesk/lib/librustdesk.so || true
      echo "=== END CUSTOM FIXUP ==="
    }
    postFixupHooks+=(myCustomFixup)
  '';

  postFixup = ''
    # wrapProgram 对普通用户场景双保险
    wrapProgram $out/bin/rustdesk \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath (libraries ++ [ libayatana-appindicator ])}:$out/share/rustdesk/lib" \
      --prefix PATH : ${lib.makeBinPath [ xdg-user-dirs ]} \
      --prefix GST_PLUGIN_PATH : "${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pipewire}/lib/gstreamer-1.0"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "rustdesk";
      desktopName = "RustDesk";
      genericName = "Remote Desktop";
      comment = "An open-source remote desktop application";
      exec = "rustdesk %u";
      icon = "rustdesk";
      terminal = false;
      type = "Application";
      startupNotify = true;
      categories = [
        "Network"
        "RemoteAccess"
        "GTK"
      ];
      keywords = [ "remote" "desktop" "vnc" "rdp" ];
      mimeTypes = [ "x-scheme-handler/rustdesk" ];
    })
  ];

  meta = {
    description = "An open-source remote desktop application designed for self-hosting, as an alternative to TeamViewer";
    homepage = "https://rustdesk.com";
    changelog = "https://github.com/rustdesk/rustdesk/releases/tag/${version}";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "rustdesk";
  };
}