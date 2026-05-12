# `/ouster/points` subscriber load test

How to run the PointCloud2 load-test framework that lives in
`my_service/workspace/src/pc_load_test/` and `vln_service/workspace/src/pc_load_test/`.

The framework spawns N PointCloud2 subscribers, each printing one line per
second with Hz / Bandwidth / Delay, so you can measure how many subscribers
the publisher can sustain at a stable 10 Hz under its declared QoS
(`RELIABLE + TRANSIENT_LOCAL`).

---

## Two ways to run

| Tool | Where you run it | Scope | Auto-cleanup |
|---|---|---|---|
| `./scripts/run_test.sh` | host (project root) | both containers | yes — both workspaces |
| `./run_local.sh` | inside one container's `~/<svc>/workspace` | that container only | yes — workspace-scoped |

Use `run_test.sh` for sweeps and the `A`/`B`/`AB` distribution selector.
Use `run_local.sh` when you've already `docker compose exec`'d into one
container and want a single-container run.

---

## Common arguments

Both scripts share the same notion of:

### `mode` — what each subscriber prints
| value | output line content |
|---|---|
| `0` *(default)* | `Hz` + `Bandwidth (MiB/s)` + `Delay (ms)` |
| `1` | `Hz` only |
| `2` | `Hz` + `Delay (ms)` |

### `topic`
Default `/ouster/points`. Any `sensor_msgs/PointCloud2` topic works.

### `duration` (seconds)
- `0` *(default)* → run until you press Ctrl-C
- any positive integer → auto-stop after that many seconds (great for batching)

`run_test.sh` enforces this with `timeout --signal=INT` *inside* the container
(SIGTERM sent to `docker compose exec` from the host doesn't reliably reach
`ros2 launch`). `run_local.sh` enforces it with a backgrounded `sleep + kill`
on the spawned PIDs.

### `prefix` / `service`
Used to keep node names unique when both containers run at the same time.
- `run_local.sh` takes a free-form `name_prefix` (use `A` in `my_service` and
  `B` in `vln_service` to match `run_test.sh`'s convention).
- `run_test.sh` takes `A`, `B`, or `AB` and derives the per-container prefix
  automatically (always `A` for `my_service`, `B` for `vln_service`).

---

## `run_test.sh` (host) — full reference

```
./scripts/run_test.sh <total> [mode] [topic] [duration] [service]

  total      2 | 4 | 6 | 8 | 10 | 12        (must be even; per container max = 6)
  mode       0 | 1 | 2                       default: 0  (Hz+BW+Delay)
  topic      sensor_msgs/PointCloud2 topic   default: /ouster/points
  duration   seconds                         default: 0  (until Ctrl-C)
  service    A | B | AB                      default: AB
               A  - all subs in my_service           (total <= 6)
               B  - all subs in vln_service          (total <= 6)
               AB - split evenly across both         (total <= 12)
```

Within each container the subs are split as `floor(N/2)` python + `ceil(N/2)`
cpp. So for 2 subs in one container you get 1 py + 1 cpp; for 6 you get
3 py + 3 cpp.

### Distribution table

| total | service `A` (my only) | service `B` (vln only) | service `AB` (split) |
|---:|---|---|---|
| 2 | my: 1py+1cpp | vln: 1py+1cpp | my:0py+1cpp + vln:0py+1cpp |
| 4 | my: 2py+2cpp | vln: 2py+2cpp | my:1py+1cpp + vln:1py+1cpp |
| 6 | my: 3py+3cpp | vln: 3py+3cpp | my:1py+2cpp + vln:1py+2cpp |
| 8 | ❌ exceeds 6 | ❌ exceeds 6 | my:2py+2cpp + vln:2py+2cpp |
| 10 | ❌ exceeds 6 | ❌ exceeds 6 | my:2py+3cpp + vln:2py+3cpp |
| 12 | ❌ exceeds 6 | ❌ exceeds 6 | my:3py+3cpp + vln:3py+3cpp |

### Recipe — every meaningful combination (25 s each, mode 0)

```bash
# total = 2
./scripts/run_test.sh  2 0 /ouster/points 25 A     # both in my_service
./scripts/run_test.sh  2 0 /ouster/points 25 B     # both in vln_service
./scripts/run_test.sh  2 0 /ouster/points 25 AB    # 1 in my + 1 in vln

# total = 4
./scripts/run_test.sh  4 0 /ouster/points 25 A
./scripts/run_test.sh  4 0 /ouster/points 25 B
./scripts/run_test.sh  4 0 /ouster/points 25 AB    # 2 + 2

# total = 6
./scripts/run_test.sh  6 0 /ouster/points 25 A
./scripts/run_test.sh  6 0 /ouster/points 25 B
./scripts/run_test.sh  6 0 /ouster/points 25 AB    # 3 + 3

# total > 6  -- AB only (each container caps at 6)
./scripts/run_test.sh  8 0 /ouster/points 25 AB    # 4 + 4
./scripts/run_test.sh 10 0 /ouster/points 25 AB    # 5 + 5
./scripts/run_test.sh 12 0 /ouster/points 25 AB    # 6 + 6
```

Mode variants — same shape, just change the second argument:
```bash
./scripts/run_test.sh 6 1 /ouster/points 25 AB     # Hz only
./scripts/run_test.sh 6 2 /ouster/points 25 AB     # Hz + Delay
```

### Sweep all six counts in one go (matches my report)
```bash
for n in 2 4 6 8 10 12; do
  ./scripts/run_test.sh $n 0 /ouster/points 25 AB
done
```

---

## `run_local.sh` (inside container) — full reference

```
./run_local.sh <total> [mode] [topic] [duration] [name_prefix]

  total        1..6                           (this container only)
  mode         0 | 1 | 2                      default: 0
  topic        default /ouster/points
  duration     seconds; 0 = until Ctrl-C
  name_prefix  free-form string               default: empty
```

Enter a container first, then run from the workspace root:

```bash
sudo docker compose exec my_service bash
cd ~/my_service/workspace
./run_local.sh 2                                  # 1py+1cpp,  /ouster/points,  forever
./run_local.sh 6 0 /ouster/points 25 A            # 3py+3cpp,  25 s,  prefix A
./run_local.sh 4 1 /ouster/points 30 A            # mode 1: Hz only
./run_local.sh 4 2 /ouster/points 30 A            # mode 2: Hz + Delay
```

For `vln_service` it's the same — just `cd ~/vln_service/workspace` and use
prefix `B` so node names don't collide if you also have a run going in
`my_service`.

### Running both containers manually for >6 total subs

Open two terminals; the prefixes (`A` / `B`) prevent node-name collisions:

```bash
# terminal 1 — my_service
sudo docker compose exec my_service bash
cd ~/my_service/workspace
./run_local.sh 6 0 /ouster/points 25 A     # 3py + 3cpp, prefix A

# terminal 2 — vln_service  (start within ~10 s of terminal 1)
sudo docker compose exec vln_service bash
cd ~/vln_service/workspace
./run_local.sh 6 0 /ouster/points 25 B     # 3py + 3cpp, prefix B
```

That's equivalent to `./scripts/run_test.sh 12 0 /ouster/points 25 AB` from
the host, but each container's output stays in its own terminal so it's
easier to read.

---

## What you should see

A healthy subscriber prints one line per second:
```
[cpp_sub_A1            ] Hz= 10.00  BW=  30.00 MiB/s  Delay=  125.4 ms  topic=/ouster/points
```

A subscriber being starved by the publisher's RELIABLE back-pressure prints:
```
[py_sub_A2             ] Hz=  2.10  BW=   6.30 MiB/s  Delay=  235.0 ms  topic=/ouster/points
```

The boundary you're looking for is the highest `total` where every line stays
at `Hz=10.00 ± 0.05`. Per the last full sweep with the publisher's
RELIABLE QoS, that ceiling is **N = 4**; from N=6 the publisher's send queue
back-pressures and throughput collapses. See `/tmp/parse_sweep.py` for the
parser that produced the per-node summary.

---

## Single-shot probe (`topic_test.py`)

Lives in both workspaces. Prints to your terminal, no launch file involved.

```bash
sudo docker compose exec my_service bash
source ~/my_service/workspace/install/setup.bash

ros2 run pc_load_test topic_test.py 0 /ouster/points     # Hz + BW + Delay
ros2 run pc_load_test topic_test.py 1 /ouster/points     # Hz only
ros2 run pc_load_test topic_test.py 2 /ouster/points     # Hz + Delay
```

---

## Pre-flight cleanup (auto)

Both `run_test.sh` and `run_local.sh` reap leftover subscribers before
spawning new ones, so you don't carry zombies between runs.

- `run_local.sh` is **workspace-scoped**: a cleanup in `my_service` only
  matches `…my_service/workspace/install/pc_load_test/…` and will not touch
  subs running in `vln_service` (and vice-versa).
- `run_test.sh` reaps **both** workspaces' subs plus any stale
  `ros2 launch load_test.launch.py` wrappers — it's a sweep coordinator, so
  this is intentional.

If you ever need to clean up by hand (e.g. you Ctrl-C'd a tmux session and
something orphaned), use the bundled helper:

```bash
./scripts/cleanup.sh
```

It reaps both workspaces' subscribers plus any `ros2 launch` wrappers and
prints `cleanup: clean` when done.

> Note: do **not** type `sudo pkill -9 -f '…/pc_load_test/…'` directly into
> the shell — `pkill -f` matches the shell's own command line and will kill
> the parent shell before the kill-list is reaped. The helper script avoids
> this by keeping the pattern inside the script file, not the calling argv.

---

## How the parallelism actually works

For the per-layer code walkthrough — which `for`-loop spawns N processes,
where each subscriber's measurement code lives, the runtime process tree
for a 12-subscriber run, etc. — see [`ARCHITECTURE.md`](./ARCHITECTURE.md).

---

## Build (once, after any code change)

```bash
./scripts/build_in_containers.sh
```

This `colcon build`s `pc_load_test` inside both containers using the
bind-mounted workspace. The Dockerfiles are unchanged by code edits, so
you don't need to rebuild the images.
