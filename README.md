# Hyphanet RPM Packaging

This repository contains the source files and scripts required to build an **RPM** (Red Hat Package Manager) package for **Hyphanet** (formerly Freenet).

The build process is fully automated using **Gradle**, ensuring reproducibility and security through checksum verification of all external assets.

## Prerequisites

You need a Linux system (Fedora, RHEL, CentOS, AlmaLinux, RockyLinux, etc.) with the following installed:

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
*   `hyphanet.spec`: The RPM specification file.
*   `wrapper.conf`, `freenet.ini`: Default configuration files.
*   `hyphanet-service`: Control script for the service.
*   `*.desktop`: Desktop entry files for the application menu.
*   `org.hyphanet.service.policy`: PolicyKit configuration for GUI management.

## Continuous Integration (CI)

The CI workflow, defined in `.github/workflows/ci.yml`, automates the build and signing of the RPM package whenever changes are pushed to the `master` branch.

### Workflow Steps
1.  **Setup**: Checks out the code, sets up Java and Gradle, and installs `rpm` and `gnupg2`.
2.  **Build**: Runs `./gradlew buildRpm` to generate the RPM.
3.  **GPG Signing**:
    *   If run on the `master` branch (or manually triggered), the workflow attempts to sign the RPM.
    *   It first tries to import a GPG private key from the `GPG_PRIVATE_KEY` repository secret.
    *   If the secret is missing or the key is invalid, it generates a temporary, ephemeral GPG key for signing.
4.  **Sign RPM**: Uses `rpmsign` to sign the generated package.
5.  **Upload Artifacts**: Uploads the signed RPM and the public GPG key as build artifacts.

### CI Hacks and Workarounds

*   **GPG Non-Interactive Mode**:
    *   The workflow configures GPG to run in a non-interactive (loopback) mode. This is necessary because a CI runner cannot prompt for a passphrase.
    *   The passphrase is provided via a pipe to the `rpmsign` command.

*   **Ephemeral GPG Key**:
    *   The ability to auto-generate a GPG key ensures that the build can succeed even without access to repository secrets (e.g., in a fork). This allows for testing the complete build and sign process in any environment.

*   **Custom RPM Sign Command**:
    *   A custom `~/.rpmmacros` file is created to override the default `rpmsign` command. This ensures that GPG is called with the correct parameters for a non-interactive environment (`--pinentry-mode loopback`, `--passphrase-fd 0`).

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
    *   Open `hyphanet.spec`.
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
3.  **Usage in SPEC file**: The `hyphanet.spec` file uses these definitions to set the package version and release, ensuring the RPM metadata always matches the build configuration.

### RPM Output Directory (RPMS.x86_64)
On some systems or configurations, `rpmbuild` may output the generated RPMs into a directory named `RPMS.x86_64` (with a dot) instead of the standard `RPMS/x86_64` (nested directory).

To handle this inconsistency:
1.  The `buildRpm` task checks for the existence of `RPMS.x86_64` after the build completes.
2.  If found, it moves the contents to the standard `RPMS/x86_64` directory.
3.  It then deletes the non-standard `RPMS.x86_64` directory.

This ensures that the final artifact is always located in `RPMS/x86_64/`, regardless of the underlying `rpmbuild` behavior.

### SPEC File Globals
The `hyphanet.spec` file starts with several `%global` definitions. These are important for ensuring a clean and consistent build, especially in automated environments:

*   **Debug Packages**:
    ```spec
    %global debug_package %{nil}
    %global _debugsource_template %{nil}
    %undefine _debugsource_packages
    %undefine _debuginfo_packages
    ```
    This block disables the automatic generation of `debuginfo` and `debugsource` packages. Since this project packages pre-compiled Java binaries, these debug packages are unnecessary and can cause issues on certain build systems (like Fedora/RHEL).

*   **Post-install Scripts**:
    ```spec
    %global __os_install_post %{nil}
    ```
    This line disables the automatic post-install scripts that `rpmbuild` might run. This gives us full control over the installation process in the `%post` section of the spec file.
