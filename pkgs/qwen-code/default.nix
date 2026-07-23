{ buildNpmPackage
, fetchFromGitHub
, nodejs_22
, jq
, git
, ripgrep
, pkg-config
, glib
, libsecret
, lib
}:

buildNpmPackage rec {
  pname = "qwen-code";
  version = "0.19.5";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${version}";
    hash = "sha256-ELeFxH7zcrZbyQALu1n59juY44GDvd/oVOKGgBTwmmg=";
  };

  npmDepsFetcherVersion = 3;
  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: uncomment in home.nix then run `nix build` to get correct hash

  nodejs = nodejs_22;

  nativeBuildInputs = [
    jq
    pkg-config
    git
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  postPatch = ''
    ${jq}/bin/jq '
      del(.packages."node_modules/node-pty") |
      del(.packages."node_modules/@lydell/node-pty") |
      del(.packages."node_modules/@lydell/node-pty-darwin-arm64") |
      del(.packages."node_modules/@lydell/node-pty-darwin-x64") |
      del(.packages."node_modules/@lydell/node-pty-linux-arm64") |
      del(.packages."node_modules/@lydell/node-pty-linux-x64") |
      del(.packages."node_modules/@lydell/node-pty-win32-arm64") |
      del(.packages."node_modules/@lydell/node-pty-win32-x64") |
      del(.packages."node_modules/keytar") |
      walk(
        if type == "object" and has("dependencies") then
          .dependencies |= with_entries(select(.key | (contains("node-pty") | not) and (contains("keytar") | not)))
        elif type == "object" and has("optionalDependencies") then
          .optionalDependencies |= with_entries(select(.key | (contains("node-pty") | not) and (contains("keytar") | not)))
        else .
        end
      ) |
      walk(
        if type == "object" and has("peerDependencies") then
          .peerDependencies |= with_entries(select(.key | (contains("node-pty") | not) and (contains("keytar") | not)))
        else .
        end
      )
    ' package-lock.json > package-lock.json.tmp && mv package-lock.json.tmp package-lock.json
  '';

  buildPhase = ''
    runHook preBuild

    npm run build --workspace=@qwen-code/channel-base
    npm run build --workspace=@qwen-code/channel-telegram
    npm run build --workspace=@qwen-code/channel-weixin
    npm run build --workspace=@qwen-code/channel-dingtalk
    npm run build --workspace=@qwen-code/web-templates
    npm run generate
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    npm prune --production
    cp -r node_modules $out/share/qwen-code/
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli.js $out/bin/qwen

    runHook postInstall
  '';

  meta = {
    description = "Coding agent that lives in digital world";
    homepage = "https://github.com/QwenLM/qwen-code";
    mainProgram = "qwen";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
