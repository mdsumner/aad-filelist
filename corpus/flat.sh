#!/usr/bin/env bash
# corpus/flat.sh -- map the corpus tree to flat release asset names and back.
# A "/" in the tree is "__" in an asset name (source ids never hold "__";
# lint-ids.R checks).
#   bash corpus/flat.sh flat   TREE_DIR FLAT_DIR
#   bash corpus/flat.sh unflat FLAT_DIR TREE_DIR
set -euo pipefail
mode=$1; src=${2%/}; dst=${3%/}
mkdir -p "$dst"
case "$mode" in
  flat)
    (cd "$src" && find . -type f ! -name '*.tmp' | sed 's|^\./||') | while read -r f; do
      cp "$src/$f" "$dst/${f//\//__}"
    done ;;
  unflat)
    for p in "$src"/*; do
      [ -f "$p" ] || continue
      f=$(basename "$p"); t=${f//__//}
      mkdir -p "$dst/$(dirname "$t")"
      cp "$p" "$dst/$t"
    done ;;
  *) echo "flat.sh: mode is flat or unflat"; exit 1 ;;
esac
