"""Spawn N python + M C++ PointCloud2 subscribers for the load test.

Examples:
  # 3 python + 3 cpp, default mode (0 = Hz+BW+Delay) on /ouster/points
  ros2 launch pc_load_test load_test.launch.py py_count:=3 cpp_count:=3

  # different mode + topic + per-service prefix so node names don't collide
  ros2 launch pc_load_test load_test.launch.py \\
      py_count:=2 cpp_count:=2 mode:=2 topic:=/ouster/points name_prefix:=B
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def _spawn(context, *_args, **_kwargs):
    py_count = int(LaunchConfiguration("py_count").perform(context))
    cpp_count = int(LaunchConfiguration("cpp_count").perform(context))
    mode = LaunchConfiguration("mode").perform(context)
    topic = LaunchConfiguration("topic").perform(context)
    prefix = LaunchConfiguration("name_prefix").perform(context)

    nodes = []
    for i in range(1, py_count + 1):
        suffix = f"{prefix}{i}" if prefix else str(i)
        nodes.append(
            Node(
                package="pc_load_test",
                executable="py_sub.py",
                name=f"py_sub_{suffix}",
                output="screen",
                emulate_tty=True,
                arguments=[suffix, mode, topic],
            )
        )
    for i in range(1, cpp_count + 1):
        suffix = f"{prefix}{i}" if prefix else str(i)
        nodes.append(
            Node(
                package="pc_load_test",
                executable="cpp_sub",
                name=f"cpp_sub_{suffix}",
                output="screen",
                emulate_tty=True,
                arguments=[suffix, mode, topic],
            )
        )
    return nodes


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument("py_count", default_value="3",
                              description="Number of python subscribers (0..3)"),
        DeclareLaunchArgument("cpp_count", default_value="3",
                              description="Number of C++ subscribers (0..3)"),
        DeclareLaunchArgument("mode", default_value="0",
                              description="0=Hz+BW+Delay, 1=Hz, 2=Hz+Delay"),
        DeclareLaunchArgument("topic", default_value="/ouster/points",
                              description="Topic to subscribe to"),
        DeclareLaunchArgument("name_prefix", default_value="",
                              description="Suffix prefix to keep node names unique across services"),
        OpaqueFunction(function=_spawn),
    ])
