# Sensor service: RealSense + Ouster on top of the Ubuntu 24 / ROS Jazzy base.
FROM ros_jazzy_base:latest

ARG ROS_DISTRO=jazzy
ENV ROS_DISTRO=${ROS_DISTRO}
ENV DEBIAN_FRONTEND=noninteractive
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      ros-${ROS_DISTRO}-ros-gz-interfaces \
      ros-${ROS_DISTRO}-realsense2-camera \
      ros-${ROS_DISTRO}-realsense2-description \
      libusb-1.0-0-dev \
      udev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/rbq/my_service/workspace \
 && chown -R rbq:rbq /home/rbq/my_service

USER rbq
WORKDIR /home/rbq/my_service/workspace
