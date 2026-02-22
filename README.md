# Hyphanet RPM Packaging

This repository contains the source files and scripts required to build an **RPM** (Red Hat Package Manager) package for **Hyphanet** (formerly Freenet).

The build process is fully automated using **Gradle**, ensuring reproducibility and security through checksum verification of all external assets.

## Prerequisites

You need a Linux system (Fedora, RHEL, CentOS, AlmaLinux, etc.) with the following installed:

1.  **Java 21** (Max required for Gradle 8.14+)
2.  **rpm-build** (Required to build the RPM)

```bash
# Fedora / RHEL / CentOS
sudo dnf install java-21-openjdk rpm-build

# Verify Java version
java -version
```

## Build Instructions

The entire build process (downloading dependencies, verifying signatures, preparing sources, and building the RPM) is handled by a single command.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/hyphanet/rpm-packaging.git
    cd rpm-packaging
    ```

2.  **Build the RPM:**
    ```bash
    ./gradlew clean buildRpm
    ```

    *Note: The first run will download Gradle and all necessary dependencies.*

3.  **Locate the RPM:**
    Once the build is successful, the RPM file will be available in:
    ```bash
    RPMS/x86_64/hyphanet-*.rpm
    ```

## Installation

To install the generated package:

```bash
sudo dnf install ./RPMS/x86_64/hyphanet-*.rpm
```

## Usage

### Managing the Service
Hyphanet runs as a systemd service.

```bash
# Start Hyphanet
sudo systemctl start hyphanet

# Stop Hyphanet
sudo systemctl stop hyphanet

# Check Status
sudo systemctl status hyphanet

# Enable at boot
sudo systemctl enable hyphanet
```

### Graphical Interface
After installation, you will find **Hyphanet** in your application menu.
- **Hyphanet**: Opens the web interface (http://127.0.0.1:8888)
- **Start Hyphanet**: Starts the background service (requires authentication)
- **Stop Hyphanet**: Stops the background service (requires authentication)

## Project Structure

*   `build.gradle.kts`: Main build script defining dependencies and tasks.
*   `prepare_sources.sh`: Script called by Gradle to assemble the source tarball.
*   `SPECS/hyphanet.spec`: The RPM specification file.
*   `wrapper.conf`, `freenet.ini`: Default configuration files.
*   `hyphanet-service`: Control script for the service.
*   `*.desktop`: Desktop entry files for the application menu.
*   `org.hyphanet.service.policy`: PolicyKit configuration for GUI management.
