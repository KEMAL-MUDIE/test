# Isaac ROS 2 Jazzy Multi-Service Workspace

A Dockerized environment for **Isaac ROS 2 (Jazzy)** featuring a sample test for sensor  (RealSense/Ouster) and a Vision-Language Navigation (VLN) service.

## 📂 Project Structure

```text
.
├── compose.yml           # Service orchestration and environment config
├── Dockerfile            # Base image build (you_image_base)
├── my_service/           # Sensor Service (RealSense & Ouster)
│   ├── Dockerfile        # Driver installations & sensor dependencies
│   └── workspace/        # ROS 2 source code and build artifacts
└── vln_service/          # Vision-Language Navigation Service
    ├── Dockerfile        # VLN specific dependencies
    └── workspace/        # ROS 2 source code and build artifacts
```

## 🚀 Quick Start Guide

### 1. Build All Services
Build the shared base image and the specific service containers:
```bash
docker compose build
```

### 2. Launch the Environment
Start both services in the background (detached mode):
```bash
docker compose up -d
```

### 3. Accessing the Containers
To open an interactive shell in a specific service, use the following:

**For the Sensor Service:**
```bash
docker compose exec my_service bash
```

**For the VLN Service:**
```bash
docker compose exec vln_service bash
```

### 4. ROS 2 Workspace Management
Once inside a container, navigate to your workspace to build and source your packages:
```bash
# Navigate to workspace
cd workspace

# Build packages
colcon build --symlink-install

# Source the workspace
source install/setup.bash
```

### 5. Shutdown
Stop and remove all running containers and networks:
```bash
docker compose down
```

## 🛠 Hardware & Network Configuration

- **Privileged Mode:** Both services run in `privileged` mode for full hardware access.
- **Device Mapping:** Host `/dev` is mounted to allow communication with USB (RealSense) and Network (Ouster) sensors.
- **Network Mode:** `host` networking is used to ensure low-latency ROS 2 Discovery (DDS) between containers and the host machine.
- **IPC/PID:** Set to `host` to allow shared memory and process monitoring across the system.

## ⚠️ Troubleshooting

- **Permission Denied (Docker Socket):** If you cannot run docker commands without `sudo`, add your user to the docker group:
  ```bash
  sudo usermod -aG docker $USER && newgrp docker
  ```
- **ROS_DISTRO Errors:** This environment is pinned to `jazzy`. Ensure your local shell or Dockerfile instructions explicitly use `jazzy` for package installations.
- **Missing Packages:** If a specific driver (e.g., Isaac ROS Nitro) is not in the apt-repo yet, clone the source into `workspace/src` and use `colcon build`.
