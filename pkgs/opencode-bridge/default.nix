{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchurl
, nodejs
, makeWrapper
, python3
}:

buildNpmPackage rec {
  pname = "opencode-bridge";
  version = "3.1.6";

  src = fetchFromGitHub {
    owner = "HNGM-HP";
    repo = "opencode-bridge";
    rev = "v${version}";
    hash = "sha256-lEUjAgAmvH6CFqRTgWGay8MfaJxd0I28+EgQ0SuNHaI=";
  };

  # Prebuilt web frontend from npm tarball
  webDist = fetchurl {
    url = "https://registry.npmjs.org/opencode-bridge/-/opencode-bridge-3.1.5.tgz";
    hash = "sha256-wjc8nKUvqmzdl6XcEQKB0CVMy2iHbpr9Tcw3QorDFgk=";
  };

  npmDepsHash = "sha256-HzwGPE6svdx5VXCL23vHPoCYhDzRlfhm4TQigSDbV34=";

  patches = [
    # Fix: admin cron routes use closure-captured `undefined` instead of global singleton.
    # Bug: lifecycle/main.ts creates admin server with cronManager=undefined BEFORE
    # bootstrap creates RuntimeCronManager. The closure captures undefined permanently.
    # Fix: use getRuntimeCronManager() lazy getter in route handlers.
    ./patches/opencode-bridge-cron-fix.patch
    # Fix: questionHandler.cleanupExpired() only called on shutdown, not periodically.
    # Expired questions stay in memory forever, blocking subsequent messages.
    # Fix: add periodic cleanup timer in main lifecycle.
    ./patches/opencode-bridge-question-expiry.patch
    # Fix: WebSocket TLS error — ws library creates its own TLS connections independent of axios.
    # Without a custom agent, it uses Node.js default agent (keepAlive=true),
    # causing stale TLS sessions → "unknown certificate verification error".
    # Fix: pass https.Agent({ keepAlive: false }) to WSClient.
    ./patches/opencode-bridge-ws-tls-fix.patch
  ];

  makeCacheWritable = true;
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    nodejs
    makeWrapper
    python3
  ];

  # Copy prebuilt web frontend and rebuild native modules
  preBuild = ''
    # Extract prebuilt dist/public from npm tarball
    tar xzf ${webDist} -C /tmp --strip-components=1 package/dist/public
    mkdir -p dist/public
    cp -r /tmp/dist/public/* dist/public/
  '';

  buildPhase = ''
    runHook preBuild
    npm rebuild better-sqlite3
    npx tsc
    runHook postBuild
  '';

  # Fix: Lark SDK axios creates defaultHttpInstance with keepAlive=true (default).
  # Long-running connections cause stale TLS sessions → certificate verification error.
  # Fix: disable keepAlive by patching the axios.create() call in Lark SDK.
  postBuild = ''
    # Patch Lark SDK axios to disable keepAlive
    LARK_SDK_INDEX="node_modules/@larksuiteoapi/node-sdk/lib/index.js"
    if [ -f "$LARK_SDK_INDEX" ]; then
      # Replace axios.create() with axios.create({ httpAgent: new http.Agent({ keepAlive: false }), httpsAgent: new https.Agent({ keepAlive: false }) })
      substituteInPlace "$LARK_SDK_INDEX" \
        --replace-quiet \
        'const defaultHttpInstance = axios__default["default"].create();' \
        'const http = require("http"); const https = require("https"); const defaultHttpInstance = axios__default["default"].create({ httpAgent: new http.Agent({ keepAlive: false }), httpsAgent: new https.Agent({ keepAlive: false }) });'
      echo "✅ Patched Lark SDK axios to disable keepAlive"
    fi
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/opencode-bridge
    cp -r . $out/lib/node_modules/opencode-bridge

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/opencode-bridge \
      --add-flags "$out/lib/node_modules/opencode-bridge/bin/opencode-bridge.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode Bridge - bridge OpenCode with instant messaging platforms";
    homepage = "https://github.com/HNGM-HP/opencode-bridge";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    mainProgram = "opencode-bridge";
  };
}
