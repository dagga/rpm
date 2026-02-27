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

## Updating Hyphanet Version

When a new version of Hyphanet is released, follow this procedure to update the RPM package:

1.  **Open `build.gradle.kts`**.
2.  **Update Version Variables**:
    *   Change `appVersion` to the new version number (e.g., `"0.7.6"`).
    *   Change `buildId` to the new build tag (e.g., `"01507"`).
3.  **Update Checksums**:
    *   The URLs for `freenet.jar`, `freenet.jar.sig`, and `freenet-ext.jar` are automatically constructed using the `buildId`.
    *   However, you **must** update the `sha256` hash for these artifacts in the `artifacts` list.
    *   *Tip*: You can temporarily set the hash to an empty string `""` or a dummy value, run the build, and copy the calculated hash from the error message or warning in the console output.
4.  **Verify Dependencies**:
    *   If other dependencies (like `wrapper`, `bcprov`, etc.) have changed, update their URLs and hashes as well.
5.  **Update SPEC Defaults**:
    *   Open `SPECS/hyphanet.spec`.
    *   Update the default values to match the new version. This ensures the spec file is valid even if used without Gradle.
    *   Look for:
        ```spec
        %{!?version: %define version 0.7.5}
        %{!?build_id: %define build_id 1506}
        ```
6.  **Run the Build**:
    ```bash
    ./gradlew clean buildRpm
    ```
7.  **Test**: Install the generated RPM and verify that Hyphanet starts correctly.

## Build Hacks

### Versioning Consistency
To ensure consistency between the Gradle build script and the RPM specification, we use a specific mechanism to pass version variables:

1.  **Definition in Gradle**: The `appVersion` and `buildId` variables are defined at the top of `build.gradle.kts`.
2.  **Passing to rpmbuild**: When the `buildRpm` task executes `rpmbuild`, it passes these values using the `--define` flag:
    ```kotlin
    commandLine(
        "/usr/bin/rpmbuild",
        "-ba",
        // ...
        "--define", "version ${appVersion}",
        "--define", "build_id ${buildId}",
        // ...
        specFile.absolutePath
    )
    ```
3.  **Usage in SPEC file**: The `SPECS/hyphanet.spec` file uses these definitions to set the package version and release, ensuring the RPM metadata always matches the build configuration.

### RPM Output Directory (RPMS.x86_64)
On some systems or configurations, `rpmbuild` may output the generated RPMs into a directory named `RPMS.x86_64` (with a dot) instead of the standard `RPMS/x86_64` (nested directory).

To handle this inconsistency:
1.  The `buildRpm` task checks for the existence of `RPMS.x86_64` after the build completes.
2.  If found, it moves the contents to the standard `RPMS/x86_64` directory.
3.  It then deletes the non-standard `RPMS.x86_64` directory.

This ensures that the final artifact is always located in `RPMS/x86_64/`, regardless of the underlying `rpmbuild` behavior.
