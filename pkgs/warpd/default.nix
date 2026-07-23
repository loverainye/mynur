{ lib
, stdenv
, fetchFromGitHub
, git
, libxi
, libxinerama
, libxft
, libxfixes
, libxtst
, libx11
, libxext
, cairo
, libxkbcommon
, wayland
, withWayland ? true
, withX ? true
}:

stdenv.mkDerivation rec {
  pname = "warpd";
  version = "unstable-2026-04-29";

  src = fetchFromGitHub {
    owner = "loverainye";
    repo = "warpd";
    rev = "14233970a2ccdcf554d01e049538ddbe2968111a";
    sha256 = "sha256-hN6AF5OGU3A9KrpWNO8NKcUID6+1XrWtgRfITsjZg8k=";
  };

  nativeBuildInputs = [ git ];

  buildInputs = lib.optionals withX [
    libxi
    libxinerama
    libxft
    libxfixes
    libxtst
    libx11
    libxext
  ] ++ lib.optionals withWayland [
    cairo
    libxkbcommon
    wayland
  ];

  postPatch = ''
    substituteInPlace mk/linux.mk \
      --replace '-m644' '-Dm644' \
      --replace '-m755' '-Dm755' \
      --replace 'cp $(TARGET)' 'cp $(TARGET) $(out)/bin/' \
      --replace 'cp files/warpd.1.gz' 'cp files/warpd.1.gz $(out)/share/man/man1/' \
      --replace 'cp files/warpd.desktop' 'cp files/warpd.desktop $(out)/share/applications/'
  '';

  makeFlags = [
    "PREFIX=$(out)"
  ] ++ lib.optional (!withWayland) "DISABLE_WAYLAND=y"
    ++ lib.optional (!withX) "DISABLE_X=y";

  meta = with lib; {
    description = "A modal keyboard driven interface for mouse manipulation";
    homepage = "https://github.com/rvaiya/warpd";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
    mainProgram = "warpd";
  };
}
