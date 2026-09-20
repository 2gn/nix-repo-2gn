{
  description = "Because I am not patient enough";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      flake = {
        overlays.default = final: prev:
          let
            craneLib = inputs.crane.mkLib final;
            callPackage = final.lib.callPackageWith (final // {inherit craneLib; });
          in
            final.lib.filesystem.packagesFromDirectoryRecursive {
              inherit callPackage;
              directory = ./pkgs;
            };
      };

      perSystem = { pkgs, system, ... }: 
        let
          craneLib = inputs.crane.mkLib pkgs;
          callPackage = pkgs.lib.callPackageWith (pkgs // {inherit craneLib; });
        in
        {
          packages = pkgs.lib.filesystem.packagesFromDirectoryRecursive {
            inherit callPackage;
            directory = ./.pkgs;
          };
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nvfetcher
            ];
          };
        };
    };
}
