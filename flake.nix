{
  description = "mynur - personal Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      packages = import ./. { inherit pkgs; };
      checkUpdates = pkgs.runCommand "check-updates" {
        nativeBuildInputs = with pkgs; [
          bash
          coreutils
          gnugrep
          python3
        ];
      } ''
        bash ${self}/tests/check-updates.sh
        touch "$out"
      '';
    in
    {
      packages.x86_64-linux = packages;

      checks.x86_64-linux = packages // {
        check-updates = checkUpdates;
      };

      apps.x86_64-linux.nix-fast-build = {
        type = "app";
        program = pkgs.lib.getExe pkgs.nix-fast-build;
        meta.description = "Build all mynur checks in parallel";
      };

      overlays.default = import ./overlay.nix;
    };
}
