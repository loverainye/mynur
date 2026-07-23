{ stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, procps
, ripgrep
, bubblewrap
, socat
, lib
}:

let
  baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";
in
stdenv.mkDerivation rec {
  pname = "claude-code";
  version = "2.1.205";

  src = fetchurl {
    url = "${baseUrl}/${version}/linux-x64/claude";
    sha256 = "sha256-3Yc0wLalA/4dF0JRhOV7OXwwuwM3oz8UcNmYX+v+Wwk=";
  };

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
    autoPatchelfHook
  ];

  strictDeps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/claude
    chmod +x $out/bin/claude

    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix PATH : ${
        lib.makeBinPath [
          procps
          ripgrep
          bubblewrap
          socat
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "claude";
  };
}
