{ stdenv
, fetchurl
, autoPatchelfHook
, makeBinaryWrapper
, ripgrep
, bubblewrap
, lib
}:

stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.144.6";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "sha256-ap3vUaCtjOpmhNjrO/AzyJ8z47xc/kkvGh4KcYRRocY=";
  };

  # Tarball contains a single file (not a directory) so we need to extract manually
  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  installPhase = ''
    runHook preInstall

    # Extract the tarball manually since dontUnpack
    tar xzf $src

    mkdir -p $out/bin
    cp codex-x86_64-unknown-linux-musl $out/bin/codex
    chmod +x $out/bin/codex

    wrapProgram $out/bin/codex --prefix PATH : ${
      lib.makeBinPath [ ripgrep bubblewrap ]
    }

    runHook postInstall
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "codex";
  };
}
