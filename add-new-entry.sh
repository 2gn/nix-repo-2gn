#!/bin/sh

repo=$1

# check if the user is using the tool right

if [ -z "$repo" ]; then
  echo "Usage: add-new-entry.sh owner/repo"
  exit 1
fi

# check if the repo is already present in the toml file

_is_already_present=$(cat ./nvfetcher.toml | rg "$repo")

if [ -n "${_is_already_present:-}" ]; then
  echo "error: program already tracked by nvfetcher"
  exit 1
fi

# heuristic extraction of package name

package_name=$(basename "$repo")


# if ! curl -fsS \
#     -H 'Accept: application/vnd.github+json' \
#     "https://api.github.com/repos/$repo/releases" \
#     -o "$tmp"
# then
#     printf 'error: could not query GitHub\n' >&2
#     exit 2
# fi



# if jq -e 'length > 0' "$tmp" >/dev/null; then
#   printf '%s has at least one release\n' "$repo"

# else
#   printf '%s has no releases\n' "$repo"
# fi


cat <<EOF >> ./nvfetcher.toml
[$package_name]
src.github = "$repo"
fetch.github = "$repo"

EOF

nix run nixpkgs#nvfetcher




