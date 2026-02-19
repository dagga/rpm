#!/bin/bash
# Hyphanet Source Preparation Script for RPM packaging
set -e

VERSION="0.7.5+1505"
BUILD_ID="01505"
BUILD_DIR="fred-build${BUILD_ID}"
ARCHIVE_NAME="hyphanet-${VERSION}.tar.gz"
RPM_SOURCES_DIR="$HOME/rpmbuild/SOURCES"

# URLs
WRAPPER_VER="3.5.51"
TANUKI_URL="https://download.tanukisoftware.com/wrapper/${WRAPPER_VER}/wrapper-linux-x86-64-${WRAPPER_VER}.tar.gz"
SEEDS_URL="https://raw.githubusercontent.com/hyphanet/java_installer/refs/heads/next/offline/seednodes.fref"

# -----------------------------------------------------------------------------
# LOCAL FILES DEFINITION
# -----------------------------------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define the 10 distinct source files
LOCAL_WRAPPER="${SCRIPT_DIR}/wrapper.conf"
LOCAL_INI="${SCRIPT_DIR}/freenet.ini"
LOCAL_SERVICE_SCRIPT="${SCRIPT_DIR}/hyphanet-service"
LOCAL_SYSTEMD_UNIT="${SCRIPT_DIR}/hyphanet.service"
LOCAL_SYSUSERS="${SCRIPT_DIR}/hyphanet.sysusers"
LOCAL_DESKTOP="${SCRIPT_DIR}/hyphanet.desktop"
LOCAL_ICON="${SCRIPT_DIR}/hyphanet.png"
LOCAL_START_DESKTOP="${SCRIPT_DIR}/hyphanet-start.desktop"
LOCAL_STOP_DESKTOP="${SCRIPT_DIR}/hyphanet-stop.desktop"
LOCAL_POLICY="${SCRIPT_DIR}/org.hyphanet.service.policy"

# Security check: All 10 files must exist
for file in "$LOCAL_WRAPPER" "$LOCAL_INI" "$LOCAL_SERVICE_SCRIPT" "$LOCAL_SYSTEMD_UNIT" "$LOCAL_SYSUSERS" "$LOCAL_DESKTOP" "$LOCAL_ICON" "$LOCAL_START_DESKTOP" "$LOCAL_STOP_DESKTOP" "$LOCAL_POLICY"; do
    if [ ! -f "$file" ]; then
        echo "CRITICAL ERROR: Source file not found -> $file"
        echo "Please verify that all source files are located in $SCRIPT_DIR"
        exit 1
    fi
done

# Ensure RPM Sources directory exists
if [ ! -d "$RPM_SOURCES_DIR" ]; then mkdir -p "$RPM_SOURCES_DIR"; fi

# Clean workspace
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/lib"

# -----------------------------------------------------------------------------
# 1. DOWNLOADS
# -----------------------------------------------------------------------------
echo "[1/5] Downloading Hyphanet JARs..."
wget -nv "https://github.com/hyphanet/fred/releases/download/build${BUILD_ID}/freenet.jar" -O "${BUILD_DIR}/freenet.jar"
wget -nv "https://github.com/hyphanet/fred/releases/download/build${BUILD_ID}/freenet-ext.jar" -O "${BUILD_DIR}/lib/freenet-ext.jar"

echo "[2/5] Downloading Dependencies..."
wget -nv "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk15on/1.59/bcprov-jdk15on-1.59.jar"  -O "${BUILD_DIR}/lib/bcprov.jar"
wget -nv "https://repo1.maven.org/maven2/net/java/dev/jna/jna/4.5.2/jna-4.5.2.jar" -O "${BUILD_DIR}/lib/jna.jar"
wget -nv "https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/4.5.2/jna-platform-4.5.2.jar" -O "${BUILD_DIR}/lib/jna-platform.jar"
wget -nv "https://repo1.maven.org/maven2/io/pebbletemplates/pebble/3.1.5/pebble-3.1.5.jar" -O "${BUILD_DIR}/lib/pebble.jar"
wget -nv "https://repo1.maven.org/maven2/org/unbescape/unbescape/1.1.6.RELEASE/unbescape-1.1.6.RELEASE.jar" -O "${BUILD_DIR}/lib/unbescape.jar"
wget -nv "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar" -O "${BUILD_DIR}/lib/slf4j-api.jar"

echo "[3/5] Downloading Tanuki Wrapper..."
wget -nv "${TANUKI_URL}" -O "wrapper.tar.gz"
tar -xzf wrapper.tar.gz
SRC_W="wrapper-linux-x86-64-${WRAPPER_VER}"
cp "${SRC_W}/bin/wrapper" "${BUILD_DIR}/hyphanet-wrapper"
cp "${SRC_W}/lib/libwrapper.so" "${BUILD_DIR}/lib/libwrapper.so"
cp "${SRC_W}/lib/wrapper.jar" "${BUILD_DIR}/lib/wrapper.jar"
rm -rf "${SRC_W}" "wrapper.tar.gz"

echo "[4/5] Retrieving Seednodes..."
wget -nv "${SEEDS_URL}" -O "${BUILD_DIR}/seednodes.fref"

# -----------------------------------------------------------------------------
# 2. COPY LOCAL FILES
# -----------------------------------------------------------------------------
echo "[5/5] Copying local configuration files..."

# Copy each file to its respective destination
cp "$LOCAL_WRAPPER" "${BUILD_DIR}/wrapper.conf"
cp "$LOCAL_INI"     "${BUILD_DIR}/freenet.ini"
cp "$LOCAL_SERVICE_SCRIPT" "${BUILD_DIR}/hyphanet-service"
cp "$LOCAL_SYSTEMD_UNIT" "${BUILD_DIR}/hyphanet.service"
cp "$LOCAL_SYSUSERS" "${BUILD_DIR}/hyphanet.sysusers"
cp "$LOCAL_DESKTOP" "${BUILD_DIR}/hyphanet.desktop"
cp "$LOCAL_ICON" "${BUILD_DIR}/hyphanet.png"
cp "$LOCAL_START_DESKTOP" "${BUILD_DIR}/hyphanet-start.desktop"
cp "$LOCAL_STOP_DESKTOP" "${BUILD_DIR}/hyphanet-stop.desktop"
cp "$LOCAL_POLICY" "${BUILD_DIR}/org.hyphanet.service.policy"


# Execution permissions
chmod +x "${BUILD_DIR}/hyphanet-wrapper"
chmod +x "${BUILD_DIR}/hyphanet-service"

# -----------------------------------------------------------------------------
# 3. ARCHIVING
# -----------------------------------------------------------------------------
echo "--- Creating archive in $RPM_SOURCES_DIR ---"
tar -czf "${RPM_SOURCES_DIR}/${ARCHIVE_NAME}" "${BUILD_DIR}"
echo "SUCCESS: Archive created properly."