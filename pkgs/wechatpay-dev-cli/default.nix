{
  stdenvNoCC,
  lib,
  fetchurl,
  makeWrapper,
  nodejs_22,
}:

let
  version = "1.2.0";
  commanderVersion = "13.1.0";

  wechatpayDevCli = fetchurl {
    url = "https://registry.npmjs.org/@tenpay/wechatpay-dev-cli/-/wechatpay-dev-cli-${version}.tgz";
    hash = "sha256-E4KmcpAfwMUTnnSN+ktzZ06Guu3LhVOfGBehv4xc4TQ=";
  };

  commander = fetchurl {
    url = "https://registry.npmjs.org/commander/-/commander-${commanderVersion}.tgz";
    hash = "sha256-1XA7ooUzbW1thv7Pep8GTiSIeUl9mMzJjKhJpi40gio=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "wechatpay-dev-cli";
  inherit version;

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    packageRoot="$out/lib/node_modules/@tenpay/wechatpay-dev-cli"
    mkdir -p "$packageRoot/node_modules/commander" "$out/bin"
    tar -xzf ${wechatpayDevCli} --strip-components=1 -C "$packageRoot"
    tar -xzf ${commander} --strip-components=1 \
      -C "$packageRoot/node_modules/commander"

    makeWrapper ${nodejs_22}/bin/node "$out/bin/wechatpay-dev-cli" \
      --add-flags "$packageRoot/dist/index.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test "$("$out/bin/wechatpay-dev-cli" --version)" = "${version}"
    "$out/bin/wechatpay-dev-cli" --help >/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Command-line development tool for WeChat Pay API v3";
    homepage = "https://www.npmjs.com/package/@tenpay/wechatpay-dev-cli";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
    mainProgram = "wechatpay-dev-cli";
  };
}
