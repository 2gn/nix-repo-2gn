echo "
[$(basename $1)]
src.github = \"$1\"
fetch.github = \"$1\"
" >> ./nvfetcher.toml

nvfetcher
