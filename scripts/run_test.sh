#!/usr/bin/env bash
# Run a /ouster/points subscriber load test with N total nodes distributed
# across the my_service and vln_service docker containers.
#
# Usage:
#   ./scripts/run_test.sh <total> [mode] [topic] [duration_sec] [service]
#
#   total       2|4|6|8|10|12  (must be even; each container caps at 6)
#   mode        0=Hz+BW+Delay (default) | 1=Hz | 2=Hz+Delay
#   topic       default /ouster/points
#   duration    seconds; 0 (default) = run until Ctrl-C
#   service     A  = all subs in my_service          (total <= 6)
#               B  = all subs in vln_service          (total <= 6)
#               AB = split evenly across both        (default; total <= 12)
#
# Within each container, subs are split as floor(N/2) python + ceil(N/2) cpp.
#
# When tmux is available the two services get side-by-side panes; otherwise
# both stream into the foreground prefixed [my ] / [vln].
set -euo pipefail
cd "$(dirname "$0")/.."

TOTAL="${1:?usage: run_test.sh <total 2|4|6|8|10|12> [mode 0|1|2] [topic] [duration_sec] [service A|B|AB]}"
MODE="${2:-0}"
TOPIC="${3:-/ouster/points}"
DURATION="${4:-0}"
SERVICE="${5:-AB}"

case "$TOTAL" in
  2|4|6|8|10|12) ;;
  *) echo "error: total must be one of 2,4,6,8,10,12" >&2; exit 2 ;;
esac
case "$MODE" in
  0|1|2) ;;
  *) echo "error: mode must be 0, 1, or 2" >&2; exit 2 ;;
esac

# Distribute total across services according to the SERVICE selector.
case "${SERVICE^^}" in
  A)
    if (( TOTAL > 6 )); then
      echo "error: service=A maxes at 6 (3 py + 3 cpp); use AB for total>6" >&2; exit 2
    fi
    MY_TOTAL=$TOTAL; VLN_TOTAL=0
    ;;
  B)
    if (( TOTAL > 6 )); then
      echo "error: service=B maxes at 6 (3 py + 3 cpp); use AB for total>6" >&2; exit 2
    fi
    MY_TOTAL=0; VLN_TOTAL=$TOTAL
    ;;
  AB|BA|BOTH)
    MY_TOTAL=$(( TOTAL / 2 )); VLN_TOTAL=$(( TOTAL - MY_TOTAL ))
    ;;
  *)
    echo "error: service must be A, B, or AB" >&2; exit 2
    ;;
esac

MY_PY=$((  MY_TOTAL / 2 )); MY_CPP=$((  MY_TOTAL - MY_PY  ))
VLN_PY=$(( VLN_TOTAL / 2 )); VLN_CPP=$(( VLN_TOTAL - VLN_PY ))

cat <<INFO
============================================================
 PointCloud2 load test
   total subscribers : $TOTAL   (service=$SERVICE)
   my_service        : py=$MY_PY  cpp=$MY_CPP    (prefix A)
   vln_service       : py=$VLN_PY  cpp=$VLN_CPP    (prefix B)
   mode              : $MODE   topic: $TOPIC
   duration_sec      : $DURATION   (0 = run until Ctrl-C)
============================================================
INFO

# Pre-flight: reap leftover subs from EITHER container's workspace, plus any
# stale `ros2 launch load_test.launch.py` wrappers. Both workspaces are
# included intentionally because run_test.sh coordinates a sweep across them.
preflight_cleanup() {
  local patterns=(
    "/home/rbq/my_service/workspace/install/pc_load_test/lib/pc_load_test/"
    "/home/rbq/vln_service/workspace/install/pc_load_test/lib/pc_load_test/"
    "load_test.launch.py"
  )
  local all="" p
  for p in "${patterns[@]}"; do
    all+=" $(pgrep -f "$p" 2>/dev/null || true)"
  done
  # de-dupe
  local pids; pids=$(echo "$all" | tr ' ' '\n' | sort -un | tr '\n' ' ')
  if [ -n "${pids// /}" ]; then
    local n; n=$(echo $pids | wc -w)
    echo "==> pre-flight: reaping $n leftover load-test process(es)"
    sudo kill -9 $pids 2>/dev/null || true
    sleep 1
  fi
}
preflight_cleanup

DC="sudo docker compose"
LAUNCH="ros2 launch pc_load_test load_test.launch.py"

# Enforce duration INSIDE the container. Signals sent to `docker compose exec`
# from the host don't reliably reach `ros2 launch` and its child nodes, so the
# old outer "sleep N; kill" pattern would leave subscribers running. The
# `timeout` binary inside the container guarantees clean shutdown:
#   --signal=INT       send SIGINT first (ros2 launch handles it gracefully)
#   --kill-after=3     SIGKILL 3 s later if anything ignores SIGINT
TIMEOUT_PREFIX=""
if [ "$DURATION" -gt 0 ]; then
  TIMEOUT_PREFIX="timeout --signal=INT --kill-after=3 $DURATION "
fi

CMD_MY="source /opt/ros/jazzy/setup.bash \
  && source /home/rbq/my_service/workspace/install/setup.bash \
  && ${TIMEOUT_PREFIX}$LAUNCH py_count:=$MY_PY cpp_count:=$MY_CPP mode:=$MODE topic:=$TOPIC name_prefix:=A"

CMD_VLN="source /opt/ros/jazzy/setup.bash \
  && source /home/rbq/vln_service/workspace/install/setup.bash \
  && ${TIMEOUT_PREFIX}$LAUNCH py_count:=$VLN_PY cpp_count:=$VLN_CPP mode:=$MODE topic:=$TOPIC name_prefix:=B"

run_my()  { $DC exec -T my_service  bash -lc "$CMD_MY"; }
run_vln() { $DC exec -T vln_service bash -lc "$CMD_VLN"; }

# tmux pane mode (only when interactive)
if command -v tmux >/dev/null 2>&1 && [ -t 1 ]; then
  SESSION="pc_load_$$"
  if (( MY_TOTAL > 0 )); then
    tmux new-session -d -s "$SESSION" -n test \
      "bash -lc 'echo \"== my_service (A) ==\"; $DC exec -T my_service bash -lc \"$CMD_MY\"; read -p \"[my_service exited - press enter]\"'"
    if (( VLN_TOTAL > 0 )); then
      tmux split-window -h -t "$SESSION:test" \
        "bash -lc 'echo \"== vln_service (B) ==\"; $DC exec -T vln_service bash -lc \"$CMD_VLN\"; read -p \"[vln_service exited - press enter]\"'"
      tmux select-layout -t "$SESSION:test" even-horizontal
    fi
  else
    # service=B only
    tmux new-session -d -s "$SESSION" -n test \
      "bash -lc 'echo \"== vln_service (B) ==\"; $DC exec -T vln_service bash -lc \"$CMD_VLN\"; read -p \"[vln_service exited - press enter]\"'"
  fi
  if [ "$DURATION" -gt 0 ]; then
    ( sleep "$DURATION"; tmux kill-session -t "$SESSION" 2>/dev/null || true ) &
  fi
  tmux attach -t "$SESSION"
  exit 0
fi

# Plain background mode
PIDS=()
cleanup() { trap - INT TERM EXIT; kill "${PIDS[@]}" 2>/dev/null || true; }
trap cleanup INT TERM EXIT

if (( MY_TOTAL > 0 )); then
  ( run_my  | sed -u 's/^/[my ] /' ) & PIDS+=($!)
fi
if (( VLN_TOTAL > 0 )); then
  ( run_vln | sed -u 's/^/[vln] /' ) & PIDS+=($!)
fi

# Duration is enforced in-container via TIMEOUT_PREFIX above; the wait below
# returns naturally when the inner ros2 launch exits.
wait "${PIDS[@]}" 2>/dev/null || true
