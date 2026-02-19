#!/bin/bash
# Hyphanet Source Preparation Script for RPM packaging
# This script now expects external assets to be provided in a directory
# specified by the DOWNLOADS_DIR environment variable.
set -e

# --- Configuration ---
VERSION="0.7.5+1505"
BUILD_ID="01505"
BUILD_DIR="fred-build${BUILD_ID}"
ARCHIVE_NAME="hyphanet-${VERSION}.tar.gz"

# --- Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# RPM Build Root is now the project root itself
RPM_BUILD_ROOT="${SCRIPT_DIR}"
RPM_SOURCES_DIR="${RPM_BUILD_ROOT}/SOURCES"

# Check if DOWNLOADS_DIR is set
if [ -z "$DOWNLOADS_DIR" ]; then
    echo "CRITICAL ERROR: DOWNLOADS_DIR environment variable is not set."
    echo "This script must be run by the Gradle 'prepareSources' task."
    exit 1
fi

# --- Local Files ---
# Define all local source files that are part of the project repository
LOCAL_FILES=(
    "${SCRIPT_DIR}/wrapper.conf"
    "${SCRIPT_DIR}/freenet.ini"
    "${SCRIPT_DIR}/hyphanet-service"
    "${SCRIPT_DIR}/hyphanet.service"
    "${SCRIPT_DIR}/hyphanet.sysusers"
    "${SCRIPT_DIR}/hyphanet.desktop"
    "${SCRIPT_DIR}/hyphanet-start.desktop"
    "${SCRIPT_DIR}/hyphanet-stop.desktop"
    "${SCRIPT_DIR}/hyphanet.png"
    "${SCRIPT_DIR}/org.hyphanet.service.policy"
)

# --- Downloaded Files ---
# Define all files expected to be in DOWNLOADS_DIR
DOWNLOADED_FILES=(
    "${DOWNLOADS_DIR}/freenet.jar"
    "${DOWNLOADS_DIR}/freenet-ext.jar"
    "${DOWNLOADS_DIR}/bcprov.jar"
    "${DOWNLOADS_DIR}/jna.jar"
    "${DOWNLOADS_DIR}/jna-platform.jar"
    "${DOWNLOADS_DIR}/pebble.jar"
    "${DOWNLOADS_DIR}/unbescape.jar"
    "${DOWNLOADS_DIR}/slf4j-api.jar"
    "${DOWNLOADS_DIR}/wrapper.tar.gz"
    "${DOWNLOADS_DIR}/seednodes.fref"
)

# --- Security Check ---
# Verify all local and downloaded files exist before starting
ALL_FILES=("${LOCAL_FILES[@]}" "${DOWNLOADED_FILES[@]}")
for file in "${ALL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "CRITICAL ERROR: Source file not found -> $file"
        exit 1
    fi
done

# --- Preparation ---
echo "[1/4] Cleaning up and creating build directory..."
if [ ! -d "$RPM_SOURCES_DIR" ]; then mkdir -p "$RPM_SOURCES_DIR"; fi
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/lib"

# --- Asset Handling ---
echo "[2/4] Copying downloaded assets..."
cp "${DOWNLOADS_DIR}/freenet.jar" "${BUILD_DIR}/"
cp "${DOWNLOADS_DIR}/freenet-ext.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/bcprov.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/jna.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/jna-platform.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/pebble.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/unbescape.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/slf4j-api.jar" "${BUILD_DIR}/lib/"
cp "${DOWNLOADS_DIR}/seednodes.fref" "${BUILD_DIR}/"

echo "[3/4] Unpacking Tanuki Wrapper..."
tar -xzf "${DOWNLOADS_DIR}/wrapper.tar.gz"
# Assuming the tarball contains a directory like wrapper-linux-x86-64-3.5.51
SRC_W=$(tar -tf "${DOWNLOADS_DIR}/wrapper.tar.gz" | head -1 | cut -f1 -d"/")
cp "${SRC_W}/bin/wrapper" "${BUILD_DIR}/hyphanet-wrapper"
cp "${SRC_W}/lib/libwrapper.so" "${BUILD_DIR}/lib/libwrapper.so"
cp "${SRC_W}/lib/wrapper.jar" "${BUILD_DIR}/lib/wrapper.jar"
rm -rf "${SRC_W}"

echo "[4/4] Copying local configuration files..."
for file in "${LOCAL_FILES[@]}"; do
    cp "$file" "${BUILD_DIR}/"
done

# Set execution permissions
chmod +x "${BUILD_DIR}/hyphanet-wrapper"
chmod +x "${BUILD_DIR}/hyphanet-service"

# --- Archiving ---
echo "--- Creating archive in $RPM_SOURCES_DIR ---"
tar -czf "${RPM_SOURCES_DIR}/${ARCHIVE_NAME}" "${BUILD_DIR}"
echo "SUCCESS: Archive created properly in $RPM_SOURCES_DIR"