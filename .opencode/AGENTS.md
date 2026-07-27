# Coding Agent Instructions: Nix Flake Package Maintenance

## 1. Objective

Maintain, update, and build Nix packages in `pkgs/` using Nix flakes and `nvfetcher`. Ensure all packages build successfully and integrate seamlessly into the flake.

## 2. Core Responsibilities

- **Package Management:** Add new `.nix` package expressions in `pkgs/`. Update source definitions using `nvfetcher` (stored in `_sources/`).
- **Flake Integrity:** Ensure `flake.nix` correctly exports all packages. Keep `flake.lock` up to date.
- **Testing & Verification:** Always test builds locally before committing. Run `nix flake check` or `nix build .#<package-name>` to validate changes.

## 3. Step-by-Step Workflow for Changes

1. **Understand the Request** — adding a new package, updating an existing one, or fixing a build error.
2. **Implement Changes** — modify `nvfetcher.toml` and run `nvfetcher`, then create/edit the package expression in `pkgs/<package-name>.nix`. Register the package in `flake.nix`.
3. **Verify and Test** — run `nix flake show` and `nix build -L .#<package-name>`.
4. **Commit & Push** — stage relevant files (`flake.nix`, `flake.lock`, `pkgs/*.nix`, `_sources/`) with a clear descriptive message.

## 4. Guidelines & Constraints

- **Idempotency & Clean Code:** Write idiomatic Nix code following `nixpkgs` standards (`stdenv.mkDerivation`, `buildGoModule`, etc.).
- **No Broken Builds:** Never push code that fails `nix build`. Debug with `-L` flag if needed.

## 5. Cachix Binary Cache Setup

### 5.1. Objective

Set up Cachix so that packages built in GitHub Actions are uploaded to a remote binary cache, allowing local machines to download pre-compiled artifacts instead of building them locally.

### 5.2. Prerequisites (User/Manual Setup)

Instruct the user to complete these one-time manual steps first:

1. Create a Cachix account on [cachix.org](https://www.cachix.org/).
2. Create a binary cache (name: `2gn`).
3. Generate a Cachix Auth Token and add it to GitHub repo secrets as `CACHIX_AUTH_TOKEN`.
4. Run `cachix use 2gn` on their local machine to configure `nix.conf`.

### 5.3. GitHub Actions Workflow

The workflow is at `.github/workflows/build.yml`. It builds all flake packages on push to `main` and pushes them to the Cachix cache using `cachix-action`.

### 5.4. Verification

- Push to `main` and check the GitHub Actions tab — build should succeed and packages should be pushed to Cachix.
- Run `nix build -L .#<package-name>` locally to confirm it downloads from the cache.

### 5.5. Fixing `cachix use` Permission Error on NixOS

If `cachix use <cache-name>` fails with "user isn't in trusted-users":

**Method A: Permanent Fix (Recommended)**
1. Add the user to `nix.settings.trusted-users` in the NixOS config:
   ```nix
   nix.settings.trusted-users = [ "root" "<your-username>" ];
   ```
2. Rebuild: `sudo nixos-rebuild switch`
3. Run `cachix use <cache-name>` again.

**Method B: Quick Fix**
```bash
sudo cachix use <cache-name>
```
