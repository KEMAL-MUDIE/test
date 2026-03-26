FROM you_image_base:latest

ARG ROS_DISTRO=jazzy
USER root

# The repo is already there for some isaac ros base images , so just update and install what's needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-colcon-common-extensions \
    ros-${ROS_DISTRO}-realsense2-camera \
    ros-${ROS_DISTRO}-realsense2-description \
    ros-${ROS_DISTRO}-ros-gz-interfaces \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/user/my_service/workspace
