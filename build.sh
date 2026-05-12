#!/usr/bin/env bash
# Build order: base image first, then the two services that FROM it.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building base image: ros_jazzy_base:latest"
docker build -t ros_jazzy_base:latest -f Dockerfile .

echo "==> Building services via docker compose"
docker compose build

echo "==> Done. Start with:  docker compose up -d"
