{ pkgs, buildGoModule }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
buildGoModule {
  inherit (sources.pwdsafety) pname version src;

  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  subPackages = [ "./cmd/pwdsafety" ];
}
