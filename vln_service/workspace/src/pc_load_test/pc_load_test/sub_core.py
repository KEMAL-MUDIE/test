"""Shared subscriber that measures Hz, bandwidth, and end-to-end delay.

Used by both the load-test python nodes and the standalone topic_test.py tool.
The same logic is implemented in src/cpp_sub.cpp for the C++ subscribers; keep
the two in sync so the printed lines are directly comparable.
"""

import threading
import time

import rclpy
from rclpy.node import Node
from rclpy.qos import (
    DurabilityPolicy,
    HistoryPolicy,
    QoSProfile,
    ReliabilityPolicy,
)
from sensor_msgs.msg import PointCloud2


HEADER_OVERHEAD_BYTES = 100  # rough fixed header cost per PointCloud2 message

# Match /ouster/points publisher (RELIABLE + TRANSIENT_LOCAL).
# VOLATILE on the sub side avoids history replay; a VOLATILE sub is
# QoS-compatible with a TRANSIENT_LOCAL pub (durability downgrade).
OUSTER_QOS = QoSProfile(
    reliability=ReliabilityPolicy.RELIABLE,
    durability=DurabilityPolicy.VOLATILE,
    history=HistoryPolicy.KEEP_LAST,
    depth=10,
)


class StatsSubscriber(Node):
    """Subscribe to a PointCloud2 topic and print Hz/BW/Delay every second.

    mode 0: Hz + Bandwidth + Delay
    mode 1: Hz only
    mode 2: Hz + Delay
    """

    def __init__(self, node_name: str, topic: str, mode: int):
        super().__init__(node_name)
        self.topic = topic
        self.mode = mode

        self._lock = threading.Lock()
        self._count = 0
        self._bytes = 0
        self._delay_sum = 0.0
        self._delay_n = 0
        self._last_print = time.monotonic()

        self.create_subscription(PointCloud2, topic, self._cb, OUSTER_QOS)
        self.create_timer(1.0, self._report)

    def _cb(self, msg: PointCloud2) -> None:
        size = len(msg.data) + HEADER_OVERHEAD_BYTES
        now_s = self.get_clock().now().nanoseconds * 1e-9
        stamp_s = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9
        delay = now_s - stamp_s
        with self._lock:
            self._count += 1
            self._bytes += size
            if stamp_s > 0.0:
                self._delay_sum += delay
                self._delay_n += 1

    def _report(self) -> None:
        with self._lock:
            now_m = time.monotonic()
            dt = now_m - self._last_print
            if dt <= 0.0:
                return
            count = self._count
            total_bytes = self._bytes
            delay_sum = self._delay_sum
            delay_n = self._delay_n
            self._count = 0
            self._bytes = 0
            self._delay_sum = 0.0
            self._delay_n = 0
            self._last_print = now_m

        hz = count / dt
        bw_mibps = (total_bytes / dt) / (1024.0 * 1024.0)
        delay_ms = (delay_sum / delay_n * 1000.0) if delay_n else float("nan")

        name = self.get_name()
        if self.mode == 0:
            line = (
                f"[{name:<22}] Hz={hz:6.2f}  BW={bw_mibps:7.2f} MiB/s  "
                f"Delay={delay_ms:7.1f} ms  topic={self.topic}"
            )
        elif self.mode == 1:
            line = f"[{name:<22}] Hz={hz:6.2f}  topic={self.topic}"
        elif self.mode == 2:
            line = (
                f"[{name:<22}] Hz={hz:6.2f}  Delay={delay_ms:7.1f} ms  "
                f"topic={self.topic}"
            )
        else:
            line = f"[{name:<22}] (unknown mode {self.mode})"
        print(line, flush=True)


def run(node_name: str, topic: str, mode: int, argv=None) -> None:
    rclpy.init(args=argv)
    node = StatsSubscriber(node_name, topic, mode)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()
