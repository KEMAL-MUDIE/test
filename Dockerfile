# Dockerfile
FROM nvcr.io/nvidia/isaac/ros:isaac_ros_054e16b5c3a328b621af47d26009c348-amd64
ARG ROS_DISTRO=jazzy
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-isaac-ros-nitros \
  && rm -rf /var/lib/apt/lists/*
