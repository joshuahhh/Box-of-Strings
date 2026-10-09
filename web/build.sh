#!/usr/bin/env bash
# Build the browser version of Box of Strings into web/dist (or the directory
# given as the first argument). Needs GHC's JavaScript backend on the PATH,
# e.g. run it as:  nix-shell web/shell.nix --run web/build.sh
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-web/dist}"
BUILD="web/.build"
GHC="${GHC:-javascript-unknown-ghcjs-ghc}"

mkdir -p "$BUILD"

# The app is compiled as-is, except that the gloss graphics library is
# replaced by the canvas-based stand-in in web/gloss.
"$GHC" --make -O2 -XHaskell2010 \
  -iapp -iweb/gloss \
  -outputdir "$BUILD" -o "$BUILD/Box_of_Strings" \
  app/Main.hs

rm -rf "$OUT"
mkdir -p "$OUT"
cp web/static/* "$OUT/"

# Stamp the build with the commit and build time: shown in the page header,
# and appended to asset URLs so browsers fetch fresh copies after a deploy.
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then COMMIT="$COMMIT-dirty"; fi
VERSION="$COMMIT-$(date -u +%Y%m%d%H%M)"
LABEL="$COMMIT · $(date -u '+%Y-%m-%d %H:%M') UTC"
sed -i -e "s|__VERSION__|$VERSION|g" -e "s|__VERSION_LABEL__|$LABEL|g" "$OUT/index.html"
cp "$BUILD/Box_of_Strings.jsexe/all.js" "$OUT/app.js"
python3 web/bundle_inputs.py input "$OUT/input-files.js"
touch "$OUT/.nojekyll"

echo "Built $OUT ($(du -sh "$OUT" | cut -f1)). Serve it with e.g.: python3 -m http.server -d $OUT"
