#!/usr/bin/env bash
# Builds the Lambda deployment package (build/lambda.zip).
# Dependencies are installed as Linux/arm64 wheels so the package runs on
# Graviton-based Lambda regardless of the developer's OS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/package"
rm -rf "$BUILD" "$ROOT/build/lambda.zip"
mkdir -p "$BUILD"

python3 -m pip install \
  --quiet \
  --target "$BUILD" \
  --platform manylinux2014_aarch64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: \
  -r "$ROOT/app/requirements.txt"

# Copy the application code (excluding caches).
rsync -a --exclude '__pycache__' "$ROOT/app" "$BUILD/"

# Slim the package: strip bytecode caches and tests.
find "$BUILD" -type d \( -name '__pycache__' -o -name 'tests' \) -prune -exec rm -rf {} +

(cd "$BUILD" && zip -qr9 "$ROOT/build/lambda.zip" .)
echo "Built $ROOT/build/lambda.zip ($(du -h "$ROOT/build/lambda.zip" | cut -f1))"
