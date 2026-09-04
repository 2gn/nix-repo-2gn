{
  description = "Because I am not patient enough";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { pkgs, system, ... }: {
        packages =
          let
            craneLib = inputs.crane.mkLib pkgs;
            callPackage = pkgs.lib.callPackageWith (pkgs // {inherit craneLib; });
          in
            pkgs.lib.filesystem.packagesFromDirectoryRecursive {
              inherit callPackage;
              directory = ./pkgs;
            };
        devShells.default = {
          commands = [
            {
              addnvdef = "./scripts/addnvdef.sh"  ;
            }
          ];
          packages = with pkgs; [
            nvfetcher
          ];
        };
      };
    };
}
