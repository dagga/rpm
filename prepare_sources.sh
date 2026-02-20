#!/bin/bash
# Hyphanet Source Preparation Script for RPM packaging
set -e

# --- Configuration ---
if [ -z "$APP_VERSION" ] || [ -z "$BUILD_ID" ]; then
    echo "CRITICAL ERROR: APP_VERSION and BUILD_ID environment variables must be set."
    exit 1
fi

VERSION="${APP_VERSION}"
BUILD_DIR_NAME="hyphanet-${VERSION}"
ARCHIVE_NAME="hyphanet-${VERSION}-${BUILD_ID}.tar.gz"

# --- Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "$RPM_BUILD_ROOT" ]; then
    RPM_BUILD_ROOT="${SCRIPT_DIR}"
fi

RPM_SOURCES_DIR="${RPM_BUILD_ROOT}/SOURCES"
TEMP_BUILD_ROOT="${RPM_BUILD_ROOT}/temp_build"
BUILD_DIR="${TEMP_BUILD_ROOT}/${BUILD_DIR_NAME}"

if [ -z "$DOWNLOADS_DIR" ]; then
    echo "CRITICAL ERROR: DOWNLOADS_DIR environment variable is not set."
    exit 1
fi

# --- Local Files ---
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
    "${SCRIPT_DIR}/org.hyphanet.hyphanet.metainfo.xml"
)

# --- Security Check ---
for file in "${LOCAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "CRITICAL ERROR: Source file not found -> $file"
        exit 1
    fi
done

# --- Preparation ---
echo "[1/4] Cleaning up and creating build directory..."
if [ ! -d "$RPM_SOURCES_DIR" ]; then mkdir -p "$RPM_SOURCES_DIR"; fi

rm -rf "${TEMP_BUILD_ROOT}"
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
SRC_W=$(tar -tf "${DOWNLOADS_DIR}/wrapper.tar.gz" | head -1 | cut -f1 -d"/")
cp "${SRC_W}/bin/wrapper" "${BUILD_DIR}/hyphanet-wrapper"
cp "${SRC_W}/lib/libwrapper.so" "${BUILD_DIR}/lib/libwrapper.so"
cp "${SRC_W}/lib/wrapper.jar" "${BUILD_DIR}/lib/wrapper.jar"
rm -rf "${SRC_W}"

echo "[4/4] Copying local configuration files..."
for file in "${LOCAL_FILES[@]}"; do
    cp "$file" "${BUILD_DIR}/"
done

chmod +x "${BUILD_DIR}/hyphanet-wrapper"
chmod +x "${BUILD_DIR}/hyphanet-service"

# --- Archiving ---
echo "--- Creating archive in $RPM_SOURCES_DIR ---"
tar -czf "${RPM_SOURCES_DIR}/${ARCHIVE_NAME}" -C "${TEMP_BUILD_ROOT}" "${BUILD_DIR_NAME}"
echo "SUCCESS: Archive created properly in $RPM_SOURCES_DIR"

# Cleanup
rm -rf "${TEMP_BUILD_ROOT}"