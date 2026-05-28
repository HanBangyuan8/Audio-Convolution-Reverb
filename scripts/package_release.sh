#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p dist
python3 -m build

VERSION="$(python3 -c 'import tomllib; print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])')"
git archive --format=zip --output="dist/audio-convolution-reverb-v${VERSION}.zip" HEAD

echo "Release artifacts:"
ls -lh dist
