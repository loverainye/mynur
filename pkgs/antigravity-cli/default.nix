{ stdenv, fetchurl, autoPatchelfHook, glibc, lib }:

let
  version = "1.1.5";
in
stdenv.mkDerivation {
  pname = "antigravity-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/google-antigravity/antigravity-cli/releases/download/${version}/agy_cli_linux_x64.tar.gz";
    sha256 = "sha256-HVhlAbihPRRuiqPH8AY09QxgNOLEKOp9ATN302MVppo=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ glibc ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp antigravity $out/bin/agy
    chmod +x $out/bin/agy
    runHook postInstall
  '';

  meta = {
    description = "Antigravity CLI - Agentic development platform command-line tool";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "agy";
  };
}
