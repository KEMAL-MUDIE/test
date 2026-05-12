# Base image: Ubuntu 24.04 Noble + ROS 2 Jazzy (official OSRF image).
# Build with:  docker build -t ros_jazzy_base:latest -f Dockerfile .
FROM ros:jazzy-ros-base

ARG ROS_DISTRO=jazzy
ENV ROS_DISTRO=${ROS_DISTRO}
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl wget git \
      gnupg lsb-release \
      python3-pip \
      python3-colcon-common-extensions \
      python3-rosdep \
      python3-vcstool \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Auto-source ROS for every interactive/login shell.
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc \
 && echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /etc/profile.d/10-ros.sh

# Replace the stock 'ubuntu' user (uid 1000 in Ubuntu 24 base) with 'rbq'
# matching the host user, so bind-mounted workspaces have correct ownership.
ARG USERNAME=rbq
ARG USER_UID=1000
ARG USER_GID=1000
RUN if id -u ubuntu >/dev/null 2>&1; then userdel -r ubuntu || true; fi \
 && (getent group ${USER_GID} >/dev/null || groupadd -g ${USER_GID} ${USERNAME}) \
 && useradd -m -s /bin/bash -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

USER rbq
WORKDIR /home/rbq
