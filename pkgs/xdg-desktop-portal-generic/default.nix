{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wrapGAppsHook4,
  libclang,
  pipewire,
  wayland,
  libxkbcommon,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "xdg-desktop-portal-generic";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "lamco-admin";
    repo = "xdg-desktop-portal-generic";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Owx4GnsVzu16Md0ARQLwkjFN5bCurhS216nguA95EDg=";
  };

  cargoHash = "sha256-m/OdKQNX4ufUBIBg5+dZyr46X9ovgKXMLa5AvdbOQ5Q=";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    libclang
    pipewire.dev  # Provides libpipewire-0.3 and libspa-0.2
    wayland
    libxkbcommon
  ];

  # Prevent double wrapping
  dontWrapGApps = true;

  postInstall = ''
    # Install portal config
    install -Dm644 data/generic.portal $out/share/xdg-desktop-portal/portals/generic.portal

    # Install D-Bus service
    install -Dm644 data/org.freedesktop.impl.portal.desktop.generic.service $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.generic.service

    # Install systemd unit
    install -Dm644 data/xdg-desktop-portal-generic.service $out/lib/systemd/user/xdg-desktop-portal-generic.service
  '';

  # Fix systemd service and D-Bus service to use the correct binary path
  postFixup = ''
    substituteInPlace $out/lib/systemd/user/xdg-desktop-portal-generic.service \
      --replace-fail '/usr/libexec/xdg-desktop-portal-generic' "$out/bin/xdg-desktop-portal-generic"
    substituteInPlace $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.generic.service \
      --replace-fail '/usr/libexec/xdg-desktop-portal-generic' "$out/bin/xdg-desktop-portal-generic"
  '';

  meta = with lib; {
    description = "Generic XDG Desktop Portal backend for Wayland compositors";
    homepage = "https://github.com/lamco-admin/xdg-desktop-portal-generic";
    license = with licenses; [ mit asl20 ];
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "xdg-desktop-portal-generic";
  };
})
