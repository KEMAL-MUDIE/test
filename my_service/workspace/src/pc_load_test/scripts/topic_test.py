#!/usr/bin/env python3
"""Standalone topic Hz / Bandwidth / Delay probe.

Usage:
  python3 topic_test.py <mode> <topic>
    mode 0: Hz + Bandwidth + Delay
    mode 1: Hz
    mode 2: Hz + Delay

Examples:
  python3 topic_test.py 0 /ouster/points
  ros2 run pc_load_test topic_test.py 1 /ouster/points
"""

import sys

from pc_load_test.sub_core import run


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "usage: topic_test.py <mode 0|1|2> <topic>\n"
            "  0 = Hz + Bandwidth + Delay\n"
            "  1 = Hz\n"
            "  2 = Hz + Delay",
            file=sys.stderr,
        )
        return 2
    mode = int(sys.argv[1])
    topic = sys.argv[2]
    run("topic_test", topic, mode)
    return 0


if __name__ == "__main__":
    sys.exit(main())
