{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  ripgrep,
  bubblewrap,
  ncurses,
  jq,
  lib,
}:

let
  target = "x86_64-unknown-linux-musl";
in
stdenv.mkDerivation rec {
  pname = "codex";
  version = "rust-v0.153.2";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/${version}/codex-package-${target}.tar.gz";
    hash = "sha256-4Q+gzueOnwvTlYgPA/1P0ifZA8p69km7wI0WSRAekiU=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    jq
  ];

  buildInputs = [ ncurses ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    tar xzf "$src" -C "$out"
    chmod +x "$out/bin/codex" "$out/bin/codex-code-mode-host"

    wrapProgram $out/bin/codex --prefix PATH : ${
      lib.makeBinPath [
        ripgrep
        bubblewrap
      ]
    }:$out/codex-path

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR"
    test -x "$out/bin/codex"
    test -x "$out/bin/codex-code-mode-host"
    test "$("$out/bin/codex" --version)" = "codex-cli ${lib.removePrefix "rust-v" version}"
    "$out/bin/codex-code-mode-host" --help | grep -Fq "Usage: codex-code-mode-host"
    "$out/codex-path/rg" --version >/dev/null
    "$out/codex-resources/bwrap" --version >/dev/null
    "$out/codex-resources/zsh/bin/zsh" --version >/dev/null
    jq -e \
      --arg version "${lib.removePrefix "rust-v" version}" \
      --arg target "${target}" \
      '.layoutVersion == 1
        and .version == $version
        and .target == $target
        and .entrypoint == "bin/codex"
        and .resourcesDir == "codex-resources"
        and .pathDir == "codex-path"' \
      "$out/codex-package.json" >/dev/null

    runHook postInstallCheck
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
