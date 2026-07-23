{ stdenv, fetchurl, unzip, lib }:

stdenv.mkDerivation rec {
  pname = "daed";
  version = "1.27.0";

  src = fetchurl {
    url = "https://github.com/daeuniverse/daed/releases/download/v${version}/daed-linux-x86_64.zip";
    sha256 = "sha256-2xR48YZEYg5xjaHGkMrMCjtYmwbGN6MopOss24BIDRM=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/daed

    # Install the daed binary
    cp daed-linux-x86_64/daed-linux-x86_64 $out/bin/daed
    chmod +x $out/bin/daed

    # Install geo data files
    cp daed-linux-x86_64/geoip.dat $out/share/daed/
    cp daed-linux-x86_64/geosite.dat $out/share/daed/
  '';

  meta = with lib; {
    description = "A Linux high-performance transparent proxy solution based on eBPF";
    homepage = "https://github.com/daeuniverse/daed";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "daed";
  };
}
