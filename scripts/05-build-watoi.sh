#!/bin/bash
# Clones the kwvg fork of watoi, applies our null-safety patch, builds with Xcode.
# usage: 05-build-watoi.sh [dir=./watoi-src]
set -euo pipefail
DIR="${1:-./watoi-src}"; HERE="$(cd "$(dirname "$0")" && pwd)"
[[ -d "$DIR/.git" ]] || git clone -q https://github.com/kwvg/watoi.git "$DIR"
cd "$DIR" && git checkout -q 2b63dd3dc192b763a5a374af0eabf2915803eff0
git apply --check "$HERE/../watoi/watoi.patch" 2>/dev/null && git apply "$HERE/../watoi/watoi.patch" || echo "(patch already applied)"
xcodebuild -project watoi.xcodeproj -target watoi -configuration Release MACOSX_DEPLOYMENT_TARGET=12.0 2>&1 | grep -E "error:|BUILD"
ls -la build/Release/watoi && echo "binary: $(pwd)/build/Release/watoi"
