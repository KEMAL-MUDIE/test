# Vision-Language Navigation service on top of the Ubuntu 24 / ROS Jazzy base.
FROM ros_jazzy_base:latest

ARG ROS_DISTRO=jazzy
ENV ROS_DISTRO=${ROS_DISTRO}
ENV DEBIAN_FRONTEND=noninteractive
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-venv \
      libglib2.0-0 \
      libsm6 \
      libxext6 \
      libxrender-dev \
      libgl1 \
    && rm -rf /var/lib/apt/lists/*

# (Optional) Add VLN python deps here, e.g.:
# RUN pip3 install --no-cache-dir --break-system-packages \
#       torch torchvision transformers opencv-python

RUN mkdir -p /home/rbq/vln_service/workspace \
 && chown -R rbq:rbq /home/rbq/vln_service

USER rbq
WORKDIR /home/rbq/vln_service/workspace
