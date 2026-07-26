# Skill: add-new-package

# Step 0: Determine project language

Query the GitHub languages API to detect the primary language:

```
curl -s https://api.github.com/repos/owner/repo/languages | jq -r 'to_entries | max_by(.value) | .key'
```

The result maps to these templates:
- **Go** → Go build (or pre-built binary if releases have binaries)
- **Rust** → Rust/crane build (or pre-built binary if releases have platform-specific assets)
- **C** → C/Meson build from source (or pre-built binary if release assets exist)
- **Other** (Python, JS, etc.) → check for release binaries first; if none, the package likely needs manual packaging

Search nixpkgs to see if it already exists:

```
nix search nixpkgs <package_name/repo_name>
```

Check if the repo has GitHub releases:

```
curl -s "https://api.github.com/repos/owner/repo/releases" | jq -r 'if length == 0 then "no releases" else "has releases" end'
```

If releases exist, inspect the first release's assets for platform-specific naming (e.g. `*-x86_64-unknown-linux-gnu.tar.gz`, `*_linux_amd64.tar.gz`). That signals a **pre-built binary** — skip source builds.

Check if it has flake.nix (200 if found, 404 when not found):

```
curl -I https://raw.githubusercontent.com/owner/repo/HEAD/flake.nix
```

# Step 1: Update nvfetcher.toml

Add an entry for the new package. Use `src.github` / `fetch.github` for repos that have GitHub releases; use `src.github_tag` / `fetch.github` for repos that only have git tags (no GitHub releases).

```
[newpkg]
src.github = "owner/newpkg"
fetch.github = "owner/newpkg"
```

# Step 2: Run nvfetcher

```
nix run nixpkgs#nvfetcher
```

This generates `_sources/generated.nix` with `pname`, `version`, and `src` for the new entry.

# Step 3: Create the package definition

Create `pkgs/newpkg.nix`. Choose the template that matches the language detected in Step 0.

## Pre-built binary (Go/Rust with upstream release assets)

```nix
{ pkgs, ... }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit (sources.newpkg) pname version src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp newpkg $out/bin/newpkg

    runHook postInstall
  '';
}
```

The binary inside the tarball may have a different name. List the archive contents to find it, or use wildcard/rename logic in `installPhase`.

If the binary is a standalone release asset (not inside a tarball), use `fetch.url` in `nvfetcher.toml` instead of `fetch.github`:

```toml
[newpkg]
src.github = "owner/newpkg"
fetch.url = "https://github.com/owner/newpkg/releases/download/$ver/newpkg-linux-x86_64"
```

Then add `dontUnpack = true` and `autoPatchelfHook` in the package:

```nix
{ pkgs, ... }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit (sources.newpkg) pname version src;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/newpkg
    chmod +x $out/bin/newpkg

    runHook postInstall
  '';
}
```

## C project (build from source with Meson)

Check if the project uses Meson (`meson.build` at root) or a plain Makefile. For Meson projects, fetch `meson.build` to check the project name and any build options:

```
curl -s "https://raw.githubusercontent.com/owner/repo/HEAD/meson.build"
```

```nix
{ pkgs, meson, ninja, pkg-config }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
pkgs.stdenv.mkDerivation {
  inherit (sources.newpkg) pname version src;

  nativeBuildInputs = [ meson ninja pkg-config ];

  # Add any C library dependencies here:
  # buildInputs = [ pkgs.glib pkgs.cairo ... ];
}
```

If the build fails due to missing dependencies, check `meson.build` for `dependency()` calls and add the corresponding nixpkgs packages to `buildInputs`.

## Go project (build from source)

Subpackage path is usually `"./cmd/<pkg>"` or `"."`. List the `cmd/` directory to confirm:

```
curl -s "https://api.github.com/repos/owner/repo/contents/cmd" | jq -r '.[].name'
```

```nix
{ pkgs, buildGoModule }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
buildGoModule {
  inherit (sources.newpkg) pname version src;

  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  subPackages = [ "./cmd/newpkg" ];
}
```

Set `vendorHash` to a fake value first, run `nix build .#newpkg`, and replace it with the hash from the error message.

## Rust project (build from source with crane)

### Check binary name in Cargo.toml

Fetch `Cargo.toml` to check the `[package] name` and any `[[bin]]` sections. The binary name may differ from the package/repo name.

```
curl -s "https://raw.githubusercontent.com/owner/repo/HEAD/Cargo.toml"
```

### If Cargo.lock exists in the repo

```nix
{ pkgs, craneLib }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
in
craneLib.buildPackage {
  inherit (sources.newpkg) pname version src;
  doCheck = false;
}
```

### If Cargo.lock does NOT exist in the repo

Generate a `Cargo.lock` locally, save it to `_sources/<pkgname>-cargo.lock`, and include it in the build:

1. Download and generate lockfile:

```
cd /tmp && curl -sL "https://github.com/owner/repo/archive/<version>.tar.gz" -o src.tar.gz && tar xzf src.tar.gz && cd <dir> && nix shell nixpkgs#cargo -c cargo generate-lockfile
```

2. Copy the generated `Cargo.lock` to `_sources/`:

```
cp /tmp/<dir>/Cargo.lock _sources/<pkgname>-cargo.lock
```

3. Create the package using crane with the lock file:

```nix
{ pkgs, craneLib }:
let
  sources = pkgs.callPackage ../_sources/generated.nix { };
  lockFile = ../_sources/<pkgname>-cargo.lock;

  srcWithLock = pkgs.runCommand "<pkgname>-src-with-lock" {} ''
    cp -r ${sources.<pkgname>.src} $out
    chmod +w $out
    cp ${lockFile} $out/Cargo.lock
  '';

  cargoVendorDir = craneLib.vendorCargoDeps {
    src = srcWithLock;
  };
in
craneLib.buildPackage {
  inherit (sources.<pkgname>) pname version;
  src = srcWithLock;
  inherit cargoVendorDir;
  doCheck = false;
}
```

4. Ensure the lock file is tracked by git:

```
git add _sources/<pkgname>-cargo.lock
```

# Step 4: Stage files for evaluation

The flake loads packages from the git tree, so new files must be staged before `nix build` can see them:

```
git add pkgs/newpkg.nix nvfetcher.toml _sources/generated.nix _sources/generated.json
```

If a cargo lock file was generated, also add it:

```
git add _sources/<pkgname>-cargo.lock
```

# Step 5: Test build

```
nix build .#newpkg
```

If the build fails with a 404 (Not Found), the repo likely doesn't have GitHub releases. Change `src.github` to `src.github_tag` in `nvfetcher.toml`, re-run step 2, then try again.

If the build fails due to missing `Cargo.lock`, follow the instructions in the Rust section above to generate one.
