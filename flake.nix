{
  description = "tcr — file tree tui in crystal";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, flake-utils }:
    (with flake-utils.lib; eachSystem defaultSystems) (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {
        devShell = import ./shell.nix { inherit pkgs; };
        packages = flake-utils.lib.flattenTree {
          tcr = pkgs.crystal.buildCrystalPackage {
            pname = "tcr";
            version = "0.0.0";

            src = ./.;

            format = "shards";
            options = [ "--release" "--progress" "--verbose" "-Dpreview_mt" ];

            crystalBinaries.tcr.src = "src/tcr.cr";

            buildInputs = with pkgs; [
              ncurses
              readline
              glibc
              fswatch
            ];
          };
        };
        
        checks = flake-utils.lib.flattenTree {
          specs = packages.tcr;
        };

        defaultPackage = packages.tcr;
      });
}
