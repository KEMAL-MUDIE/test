#!/usr/bin/env bash
# Build the pc_load_test package inside both service containers.
set -euo pipefail
cd "$(dirname "$0")/.."

DC="sudo docker compose"

build_one() {
  local svc="$1" ws="$2"
  echo "==> [$svc] colcon build in $ws"
  $DC exec -T "$svc" bash -lc "
    set -e
    source /opt/ros/jazzy/setup.bash
    cd '$ws'
    colcon build --symlink-install --packages-select pc_load_test
  "
}

build_one my_service  /home/rbq/my_service/workspace
build_one vln_service /home/rbq/vln_service/workspace

echo "==> Build complete in both containers."
