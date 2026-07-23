{ pkgs, buildGoModule }:
let
  # Load the automatically generated hashes
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
buildGoModule {
  inherit (sources.whosthere) pname version src;

  vendorHash = "sha256-qVUJZkf9mUOn+9zWDSlRw6mosgQ7TetqpIk2SpYrdCs=";

  # nativeBuildInputs = [
  #   pkgs.pkg-config
  # ];

  # C libraries the application needs to link against
  buildInputs = [
  ];

  # subPackages = [ "cmd/dskDitto" ];
}
