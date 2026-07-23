# qoder: AI-powered code editor
# Electron 应用，使用共享的 X11/GUI 运行时依赖
{ stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, lib
, nss
, nspr
, dbus
, systemd
, gcc
, alsa-lib
, gtk3
, atk
, at-spi2-atk
, at-spi2-core
, pango
, cairo
, mesa
, libx11
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxrandr
, libxcb
, libxkbcommon
, libxkbfile
, cups
, expat
}:

stdenv.mkDerivation rec {
  pname = "qoder";
  version = "1.16.1";

  src = fetchurl {
    url = "https://download.qoder.com/release/latest/qoder_amd64.deb";
    sha256 = "sha256-erqVxhtTrR8Fxmnajx5pw1xqs4rtHDlhUkDsySKDd1k=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  # 共享的 Electron 运行时依赖 + qoder 特有依赖
  buildInputs = [
    # 基础运行时
    nss nspr dbus systemd gcc

    # 音频
    alsa-lib

    # 图形和GUI
    gtk3 atk at-spi2-atk at-spi2-core pango cairo mesa

    # X11 相关
    libx11 libxcomposite libxdamage libxext libxfixes
    libxrandr libxcb libxkbcommon libxkbfile

    # 其他系统库
    cups expat
  ];

  unpackPhase = ''
    ar x ${src}
    tar xf data.tar.xz
  '';

  installPhase = ''
    # 安装整个 qoder 目录
    mkdir -p $out/share/qoder
    cp -r usr/share/qoder/* $out/share/qoder/

    # 创建 wrapper
    makeWrapper $out/share/qoder/qoder $out/bin/qoder

    # 安装桌面文件
    mkdir -p $out/share/applications
    cp usr/share/applications/*.desktop $out/share/applications/
    sed -i "s|Exec=.*|Exec=qoder|" $out/share/applications/*.desktop

    # 安装图标
    mkdir -p $out/share/pixmaps
    cp usr/share/pixmaps/Qoder.png $out/share/pixmaps/qoder.png
  '';

  meta = {
    description = "Qoder - AI-powered code editor";
    homepage = "https://qoder.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "qoder";
  };
}
