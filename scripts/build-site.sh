#!/usr/bin/env bash
# docs/ -> /, web/ -> /app. Same shape as nimble's site build.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf dist && mkdir -p dist/app
cp docs/* dist/
cp web/* dist/app/
cp data/cities.json dist/app/cities.json
echo "dist/ built: $(find dist -type f | wc -l | tr -d ' ') files"
