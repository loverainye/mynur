{ stdenv
, fetchurl
, lib
, autoPatchelfHook
, zlib
, openssl
}:

stdenv.mkDerivation rec {
  pname = "qoder-cli";
  version = "1.1.1";

  src = fetchurl {
    url = "https://qoder-ide.oss-accelerate.aliyuncs.com/qodercli/releases/${version}/qodercli-linux-x64.tar.gz";
    sha256 = "sha256-IbYOPQ2ducNeU4XG2VI2KOGHNbe+W7vBqRmW5O1qKyo=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  dontStrip = true;

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp qodercli $out/bin/qodercli
    chmod +x $out/bin/qodercli
  '';

  meta = with lib; {
    description = "Qoder CLI - Command line interface for Qoder AI coding assistant";
    homepage = "https://qoder.com";
    license = licenses.unfree;
    platforms = platforms.linux;
    mainProgram = "qodercli";
  };
}
