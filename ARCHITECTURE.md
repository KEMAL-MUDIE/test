# `pc_load_test` — code walkthrough & parallelism

Companion to [`LOAD_TEST.md`](./LOAD_TEST.md). That doc tells you *how* to run
the load test; this one tells you *what the code is doing under the hood* and
*where the per-N parallelism actually comes from*.

Every subscriber is its own OS process. There's no threading inside any one
subscriber — the parallelism comes from spawning N processes. Below is the
full call chain from `./scripts/run_test.sh 12 0 /ouster/points 25 AB` down
to twelve concurrent DDS readers.

---

## Layer 1 — host script decides per-container counts

`scripts/run_test.sh:39-61` turns the user's `<total>` and `<service>` into
four numbers: `MY_PY`, `MY_CPP`, `VLN_PY`, `VLN_CPP`.

```bash
case "${SERVICE^^}" in
  A)  MY_TOTAL=$TOTAL; VLN_TOTAL=0  ;;
  B)  MY_TOTAL=0; VLN_TOTAL=$TOTAL  ;;
  AB|BA|BOTH)
      MY_TOTAL=$(( TOTAL / 2 )); VLN_TOTAL=$(( TOTAL - MY_TOTAL ))  ;;
esac

MY_PY=$((  MY_TOTAL / 2 )); MY_CPP=$((  MY_TOTAL - MY_PY  ))
VLN_PY=$(( VLN_TOTAL / 2 )); VLN_CPP=$(( VLN_TOTAL - VLN_PY ))
```

Worked example: `total=12 service=AB` → `MY_TOTAL=6`, `VLN_TOTAL=6` → per
container `MY_PY=3 MY_CPP=3` and `VLN_PY=3 VLN_CPP=3`. Total = 12.

---

## Layer 2 — host hands those counts to each container's launch

`scripts/run_test.sh:115-119` builds one `ros2 launch` command per
container and arms a per-container `timeout` if `duration > 0`:

```bash
CMD_MY="… && ${TIMEOUT_PREFIX}$LAUNCH py_count:=$MY_PY cpp_count:=$MY_CPP \
        mode:=$MODE topic:=$TOPIC name_prefix:=A"
CMD_VLN="… && ${TIMEOUT_PREFIX}$LAUNCH py_count:=$VLN_PY cpp_count:=$VLN_CPP \
        mode:=$MODE topic:=$TOPIC name_prefix:=B"
```

`scripts/run_test.sh:147-152` sends each command into its container in
parallel via `&`:

```bash
( run_my  | sed -u 's/^/[my ] /' ) & PIDS+=($!)   # docker compose exec my_service ...
( run_vln | sed -u 's/^/[vln] /' ) & PIDS+=($!)   # docker compose exec vln_service ...
```

---

## Layer 3 — the actual N-fanout

`my_service/workspace/src/pc_load_test/launch/load_test.launch.py:25-49` is
the `for`-loop that turns `py_count=3 cpp_count=3` into 6 separate `Node`
actions:

```python
nodes = []
for i in range(1, py_count + 1):              # ← N python subscribers
    suffix = f"{prefix}{i}" if prefix else str(i)
    nodes.append(Node(
        package="pc_load_test",
        executable="py_sub.py",
        name=f"py_sub_{suffix}",              # py_sub_A1, py_sub_A2, py_sub_A3
        output="screen", emulate_tty=True,
        arguments=[suffix, mode, topic],
    ))
for i in range(1, cpp_count + 1):             # ← M C++ subscribers
    suffix = f"{prefix}{i}" if prefix else str(i)
    nodes.append(Node(
        package="pc_load_test",
        executable="cpp_sub",
        name=f"cpp_sub_{suffix}",             # cpp_sub_A1, cpp_sub_A2, cpp_sub_A3
        output="screen", emulate_tty=True,
        arguments=[suffix, mode, topic],
    ))
return nodes
```

`ros2 launch` takes that list of `Node` actions and `fork()/exec()`s **one
OS process per Node**. So `py_count=3 cpp_count=3` → 6 child processes, all
started simultaneously. **That is where the parallelism happens.**

`run_local.sh` does the same fanout without `ros2 launch` — see
`my_service/workspace/run_local.sh:60-67`:

```bash
pids=()
for ((i=1; i<=PY; i++)); do
  ros2 run pc_load_test py_sub.py "${PREFIX}${i}" "$MODE" "$TOPIC" &
  pids+=($!)
done
for ((i=1; i<=CPP; i++)); do
  ros2 run pc_load_test cpp_sub "${PREFIX}${i}" "$MODE" "$TOPIC" &
  pids+=($!)
done
```

The trailing `&` is what makes them parallel — bash forks each `ros2 run`
into the background and continues to the next iteration immediately.

---

## Layer 4 — each spawned process is one independent subscriber

Each of the N processes runs the same code: create one subscription, spin
forever. No threading, no fanout — just one DDS reader per process.

Python — `my_service/workspace/src/pc_load_test/scripts/py_sub.py:18-25`:
```python
suffix = sys.argv[1]
mode   = int(sys.argv[2])
topic  = sys.argv[3]
run(f"py_sub_{suffix}", topic, mode)         # → calls sub_core.run() below
```

The single subscription —
`my_service/workspace/src/pc_load_test/pc_load_test/sub_core.py:42-44`:
```python
self.create_subscription(PointCloud2, topic, self._cb, OUSTER_QOS)
self.create_timer(1.0, self._report)
```

The spin loop — `sub_core.py:97-99`:
```python
node = StatsSubscriber(node_name, topic, mode)
rclpy.spin(node)              # one spin loop per process
```

C++ side mirrors it — `src/cpp_sub.cpp:36-43`:
```cpp
sub_ = create_subscription<sensor_msgs::msg::PointCloud2>(
  topic, qos,
  [this](sensor_msgs::msg::PointCloud2::ConstSharedPtr msg) { this->cb(msg); });
timer_ = create_wall_timer(std::chrono::seconds(1),
                           [this]() { this->report(); });
```
…and `src/cpp_sub.cpp:128-132`:
```cpp
auto node = std::make_shared<StatsSubscriber>("cpp_sub_" + suffix, topic, mode);
rclcpp::spin(node);           // one spin loop per process
```

---

## Process tree at runtime — what 12 parallel subscribers looks like

```
your shell
  └── ./scripts/run_test.sh 12 0 /ouster/points 25 AB
        ├── docker exec my_service  ros2 launch …  py_count:=3 cpp_count:=3   &
        │                              └── ros2 launch fans out:
        │                                    ├── py_sub.py   A1   ← OS process #1
        │                                    ├── py_sub.py   A2   ← OS process #2
        │                                    ├── py_sub.py   A3   ← OS process #3
        │                                    ├── cpp_sub     A1   ← OS process #4
        │                                    ├── cpp_sub     A2   ← OS process #5
        │                                    └── cpp_sub     A3   ← OS process #6
        │
        └── docker exec vln_service ros2 launch …  py_count:=3 cpp_count:=3   &
                                       └── ros2 launch fans out:
                                             ├── py_sub.py   B1   ← OS process #7
                                             ├── py_sub.py   B2   ← OS process #8
                                             ├── py_sub.py   B3   ← OS process #9
                                             ├── cpp_sub     B1   ← OS process #10
                                             ├── cpp_sub     B2   ← OS process #11
                                             └── cpp_sub     B3   ← OS process #12
```

So **"12 subscribers in parallel" = 12 independent OS processes**, each
with its own DDS reader on `/ouster/points`. The OS scheduler runs them
concurrently; DDS delivers each message to all 12 readers; each reader
counts what it got and prints once a second. None of them know about the
others.

We do **not** run `ros2 topic hz` anywhere in the pipeline — the
subscribers themselves measure (`sub_core.py:42-44` for python,
`cpp_sub.cpp:36-43` for C++).

---

## Summary — where the parallelism lives

The two layers that actually *create* the parallelism:

1. **`load_test.launch.py:26-49`** — the `for`-loops that build N `Node`
   actions, which `ros2 launch` then forks one process per.
2. **`run_local.sh:60-67`** — the `for`-loops with trailing `&` that
   background-fork N `ros2 run` invocations directly (when not using
   launch).

Everything below those layers is single-threaded per-process: one
subscription + one 1-Hz reporting timer. Everything above them is just
arithmetic on `total / service` to decide how many of each kind go into
each container.
