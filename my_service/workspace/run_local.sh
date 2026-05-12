#!/usr/bin/env bash
# Run N PointCloud2 subscribers locally in THIS container.
#
# Usage:
#   ./run_local.sh <total: 1..6> [mode: 0|1|2] [topic] [duration_sec] [name_prefix]
#
# Split: floor(N/2) python  +  ceil(N/2) cpp   (max 3 py + 3 cpp per container)
#   N=1 -> 0py 1cpp     N=4 -> 2py 2cpp
#   N=2 -> 1py 1cpp     N=5 -> 2py 3cpp
#   N=3 -> 1py 2cpp     N=6 -> 3py 3cpp
#
# Each subscriber prints one line per second:
#   [name] Hz=...  BW=... MiB/s  Delay=... ms  topic=...
# Ctrl-C to stop, or pass duration_sec to auto-stop.
#
# Tip: if you run this in BOTH containers at once, pass a distinct
# name_prefix in each so node names don't collide. Example:
#   my_service:  ./run_local.sh 6 0 /ouster/points 0 A
#   vln_service: ./run_local.sh 6 0 /ouster/points 0 B
set -o pipefail

WS_ROOT="$(cd "$(dirname "$0")" && pwd)"

TOTAL="${1:?usage: ./run_local.sh <total 1..6> [mode 0|1|2] [topic] [duration_sec] [name_prefix]}"
MODE="${2:-0}"
TOPIC="${3:-/ouster/points}"
DURATION="${4:-0}"
PREFIX="${5:-}"

if (( TOTAL < 1 || TOTAL > 6 )); then
  echo "error: total must be 1..6 (max 3 py + 3 cpp per container)" >&2
  exit 2
fi
case "$MODE" in 0|1|2) ;; *) echo "error: mode must be 0, 1, or 2" >&2; exit 2 ;; esac

PY=$(( TOTAL / 2 ))
CPP=$(( TOTAL - PY ))

cat <<INFO
============================================================
 Local PointCloud2 load test (this container only)
   total subscribers : $TOTAL   (py=$PY  cpp=$CPP)
   mode              : $MODE   topic: $TOPIC
   duration_sec      : $DURATION   (0 = run until Ctrl-C)
   name prefix       : '${PREFIX}'
   workspace         : $WS_ROOT
============================================================
INFO

# Pre-flight: reap any leftover subscribers from a previous interrupted run
# in THIS workspace only. Scoped by $WS_ROOT so a cleanup in my_service does
# not touch vln_service's processes (or vice-versa) even though the containers
# share the host PID namespace.
preflight_cleanup() {
  local pat="$WS_ROOT/install/pc_load_test"
  local pids
  pids=$(pgrep -f "$pat" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    local n; n=$(echo $pids | wc -w)
    echo "==> pre-flight: reaping $n leftover subscriber(s) from $WS_ROOT"
    kill -9 $pids 2>/dev/null || sudo -n kill -9 $pids 2>/dev/null || true
    sleep 1
    local left; left=$(pgrep -f "$pat" 2>/dev/null || true)
    if [ -n "$left" ]; then
      echo "    warning: $(echo $left | wc -w) survivor(s) - may need cleanup from the host"
    fi
  fi
}
preflight_cleanup

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
if [ ! -f "$WS_ROOT/install/setup.bash" ]; then
  echo "error: $WS_ROOT/install/setup.bash not found - build first:" >&2
  echo "  cd $WS_ROOT && colcon build --symlink-install --packages-select pc_load_test" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$WS_ROOT/install/setup.bash"

pids=()
for ((i=1; i<=PY; i++)); do
  ros2 run pc_load_test py_sub.py "${PREFIX}${i}" "$MODE" "$TOPIC" &
  pids+=($!)
done
for ((i=1; i<=CPP; i++)); do
  ros2 run pc_load_test cpp_sub "${PREFIX}${i}" "$MODE" "$TOPIC" &
  pids+=($!)
done

cleanup() {
  trap - INT TERM EXIT
  kill -INT  "${pids[@]}" 2>/dev/null || true
  sleep 1
  kill -KILL "${pids[@]}" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

if (( DURATION > 0 )); then
  ( sleep "$DURATION"; cleanup ) &
fi

wait "${pids[@]}" 2>/dev/null || true
