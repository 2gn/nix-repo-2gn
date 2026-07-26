{ pkgs, craneLib }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };

  lockFile = ../_sources/bbcli-cargo.lock;

  srcWithLock = pkgs.runCommand "bbcli-src-with-lock" {} ''
    cp -r ${sources.bbcli.src} $out
    chmod +w $out
    cp ${lockFile} $out/Cargo.lock
  '';

  cargoVendorDir = craneLib.vendorCargoDeps {
    src = srcWithLock;
  };
in
craneLib.buildPackage {
  inherit (sources.bbcli) pname version;
  src = srcWithLock;
  inherit cargoVendorDir;
  doCheck = false;
}
