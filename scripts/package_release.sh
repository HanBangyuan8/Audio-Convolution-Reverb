#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p dist

PYTHON_BIN="${PYTHON:-python3}"
if [[ -x ".venv/bin/python" ]]; then
  PYTHON_BIN=".venv/bin/python"
fi

"$PYTHON_BIN" -m build --no-isolation

VERSION="$("$PYTHON_BIN" -c 'import tomllib; print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])')"
git archive --format=zip --output="dist/Audio-Convolution-Reverb-v${VERSION}-source.zip" HEAD

echo "Release artifacts:"
ls -lh dist
