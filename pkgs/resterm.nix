{ pkgs, buildGoModule }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
buildGoModule {
  inherit (sources.resterm) pname version src;

  vendorHash = "sha256-AYe9qB4t1ocL3qQpwXz1Rm91q238rD68ewcwjUxO9nM=";

  subPackages = [ "./cmd/resterm" ];
}
