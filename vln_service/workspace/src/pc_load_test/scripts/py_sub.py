#!/usr/bin/env python3
"""One python PointCloud2 subscriber instance for the load test.

Usage (after `source install/setup.bash`):
  ros2 run pc_load_test py_sub.py <name_suffix> <mode 0|1|2> <topic>

Or via the bundled launch file (recommended):
  ros2 launch pc_load_test load_test.launch.py py_count:=3 cpp_count:=3
"""

import sys

from pc_load_test.sub_core import run


def main() -> int:
    if len(sys.argv) < 4:
        print(
            "usage: py_sub.py <name_suffix> <mode 0|1|2> <topic>",
            file=sys.stderr,
        )
        return 2
    suffix = sys.argv[1]
    mode = int(sys.argv[2])
    topic = sys.argv[3]
    run(f"py_sub_{suffix}", topic, mode)
    return 0


if __name__ == "__main__":
    sys.exit(main())
