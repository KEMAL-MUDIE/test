# Vision-Language Navigation (VLN) Service Dockerfile
FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv \
        git wget curl \
        build-essential \
        ca-certificates \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender-dev \
        && rm -rf /var/lib/apt/lists/*

# (Optional) Install additional vision-language navigation dependencies here
# RUN pip3 install torch torchvision transformers opencv-python

# Create workspace directory
RUN mkdir -p /home/user/vln_service/workspace
WORKDIR /home/user/vln_service/workspace

# Set default command
CMD ["/bin/bash"]
