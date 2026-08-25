{
  stdenvNoCC,
  lib,
  fetchurl,
  nodejs_22,
  autoPatchelfHook,
  makeWrapper,
  gcc,
  alsa-lib,
  libpulseaudio,
  libjack2,
}:

let
  version = "0.21.0";

  qwenCode = fetchurl {
    url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
    hash = "sha256-YvpepASo0faU7cVERrvUym06aeCQ7Fl1l3/1GRjSrso=";
  };

  audioCapture = fetchurl {
    url = "https://registry.npmjs.org/@qwen-code/audio-capture/-/audio-capture-${version}.tgz";
    hash = "sha256-einsD5BWXhNKPKWsQ6qq+SGsWYOp4LGIny2+UConsaY=";
  };

  nodeGypBuild = fetchurl {
    url = "https://registry.npmjs.org/node-gyp-build/-/node-gyp-build-4.8.4.tgz";
    hash = "sha256-lARQ+0FYvdwjrhVkMqZzOKTXq2pYW2OcYbOwoU0rrCQ=";
  };

  nodePty = fetchurl {
    url = "https://registry.npmjs.org/@lydell/node-pty/-/node-pty-1.2.0-beta.10.tgz";
    hash = "sha256-6Oa9SQc5S8tFUdr9e24Q1SRiXNdueAJ+FXTkshSlxQk=";
  };

  nodePtyLinux = fetchurl {
    url = "https://registry.npmjs.org/@lydell/node-pty-linux-x64/-/node-pty-linux-x64-1.2.0-beta.10.tgz";
    hash = "sha256-PAFJZMjf+XJ3UkPwF9usyTGQrB99zg+oHYQsqoW4IfI=";
  };

  clipboard = fetchurl {
    url = "https://registry.npmjs.org/@teddyzhu/clipboard/-/clipboard-0.0.5.tgz";
    hash = "sha256-19PmObu+bj0Uck3KRJz5+gFE7fvSfbg9LtEgrj6gObA=";
  };

  clipboardLinux = fetchurl {
    url = "https://registry.npmjs.org/@teddyzhu/clipboard-linux-x64-gnu/-/clipboard-linux-x64-gnu-0.0.5.tgz";
    hash = "sha256-RQp1kB7SSvrT3oSUFBVjWLfZoBVCLEDqp61Kqzzv3+E=";
  };

  audioLibraries = [
    alsa-lib
    libpulseaudio
    libjack2
  ];
in
stdenvNoCC.mkDerivation {
  pname = "qwen-code";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ gcc.cc.lib ] ++ audioLibraries;

  installPhase = ''
    runHook preInstall

    packageRoot="$out/share/qwen-code"
    nodeModules="$packageRoot/node_modules"
    mkdir -p "$packageRoot" \
      "$nodeModules/@qwen-code/audio-capture" \
      "$nodeModules/@lydell/node-pty" \
      "$nodeModules/@lydell/node-pty-linux-x64" \
      "$nodeModules/@teddyzhu/clipboard" \
      "$nodeModules/@teddyzhu/clipboard-linux-x64-gnu" \
      "$nodeModules/node-gyp-build"

    tar -xzf ${qwenCode} --strip-components=1 -C "$packageRoot"
    tar -xzf ${audioCapture} --strip-components=1 \
      -C "$nodeModules/@qwen-code/audio-capture"
    tar -xzf ${nodeGypBuild} --strip-components=1 \
      -C "$nodeModules/node-gyp-build"
    tar -xzf ${nodePty} --strip-components=1 \
      -C "$nodeModules/@lydell/node-pty"
    tar -xzf ${nodePtyLinux} --strip-components=1 \
      -C "$nodeModules/@lydell/node-pty-linux-x64"
    tar -xzf ${clipboard} --strip-components=1 \
      -C "$nodeModules/@teddyzhu/clipboard"
    tar -xzf ${clipboardLinux} --strip-components=1 \
      -C "$nodeModules/@teddyzhu/clipboard-linux-x64-gnu"

    find "$packageRoot/vendor/ripgrep" -mindepth 1 -maxdepth 1 \
      -type d ! -name x64-linux -exec rm -rf {} +
    find "$nodeModules/@qwen-code/audio-capture/prebuilds" \
      -mindepth 1 -maxdepth 1 -type d ! -name linux-x64 \
      -exec rm -rf {} +

    mkdir -p "$out/bin"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/qwen" \
      --add-flags "$packageRoot/cli-entry.js" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath audioLibraries}"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test "$("$out/bin/qwen" --version)" = ${version}
    "$out/bin/qwen" --help >/dev/null
    "$out/share/qwen-code/vendor/ripgrep/x64-linux/rg" --version >/dev/null

    ${nodejs_22}/bin/node - "$out/share/qwen-code" <<'NODE'
    const path = require("node:path");
    const { pathToFileURL } = require("node:url");

    const packageRoot = process.argv[2];
    const nodeModules = path.join(packageRoot, "node_modules");
    const pty = require(path.join(nodeModules, "@lydell/node-pty"));
    const clipboard = require(path.join(nodeModules, "@teddyzhu/clipboard"));

    if (typeof clipboard.getClipboardText !== "function") {
      throw new Error("clipboard native module did not load");
    }

    (async () => {
      const { createNativeAudioCaptureBackend } = await import(pathToFileURL(path.join(
        nodeModules,
        "@qwen-code/audio-capture/dist/index.js",
      )));
      createNativeAudioCaptureBackend();

      await new Promise((resolve, reject) => {
        const child = pty.spawn(process.execPath, [
          "-e",
          "process.stdout.write('pty-ok')",
        ]);
        let output = "";
        const timeout = setTimeout(() => {
          child.kill();
          reject(new Error("PTY subprocess timed out"));
        }, 5000);
        child.onData((data) => {
          output += data;
        });
        child.onExit(({ exitCode }) => {
          clearTimeout(timeout);
          if (exitCode !== 0 || !output.includes("pty-ok")) {
            reject(new Error(`PTY subprocess failed: ''${exitCode}: ''${output}`));
          } else {
            resolve();
          }
        });
      });
    })().catch((error) => {
      console.error(error);
      process.exitCode = 1;
    });
    NODE

    runHook postInstallCheck
  '';

  meta = {
    description = "Coding agent that lives in digital world";
    homepage = "https://github.com/QwenLM/qwen-code";
    mainProgram = "qwen";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
