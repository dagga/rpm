#!/bin/bash
# Hyphanet Source Preparation Script for RPM packaging
set -e

VERSION="0.7"
BUILD_ID="01505"
BUILD_DIR="fred-build${BUILD_ID}"
ARCHIVE_NAME="hyphanet-${VERSION}.tar.gz"
RPM_SOURCES_DIR="$HOME/rpmbuild/SOURCES"

# Path definitions
INSTALL_PATH="/opt/hyphanet"
DATA_PATH="/var/lib/hyphanet"
LOG_PATH="/var/log/hyphanet"

# URLs
WRAPPER_VER="3.5.51"
TANUKI_URL="https://download.tanukisoftware.com/wrapper/${WRAPPER_VER}/wrapper-linux-x86-64-${WRAPPER_VER}.tar.gz"
SEEDS_URL="https://raw.githubusercontent.com/hyphanet/java_installer/refs/heads/next/offline/seednodes.fref"

# current directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCAL_CONF="${SCRIPT_DIR}/wrapper.conf"

# Check if wrapper.conf is locally present
if [ ! -f "$LOCAL_CONF" ]; then
    echo "ERREUR : Le fichier 'wrapper.conf' est introuvable dans $SCRIPT_DIR"
    echo "Veuillez créer ce fichier avant de lancer le script."
    exit 1
fi

# Ensure RPM Sources directory exists
if [ ! -d "$RPM_SOURCES_DIR" ]; then mkdir -p "$RPM_SOURCES_DIR"; fi

# Clean workspace
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/lib"

# 1. DOWNLOADS
echo "[1/7] Downloading Hyphanet ..."
wget -nv "https://github.com/hyphanet/fred/releases/download/build${BUILD_ID}/freenet.jar" -O "${BUILD_DIR}/freenet.jar"
wget -nv "https://github.com/hyphanet/fred/releases/download/build${BUILD_ID}/freenet-ext.jar" -O "${BUILD_DIR}/lib/freenet-ext.jar"

echo "[2/7] Downloading Dependencies..."
wget -nv "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk15on/1.59/bcprov-jdk15on-1.59.jar"  -O "${BUILD_DIR}/lib/bcprov.jar"
wget -nv "https://repo1.maven.org/maven2/net/java/dev/jna/jna/4.5.2/jna-4.5.2.jar" -O "${BUILD_DIR}/lib/jna.jar"
wget -nv "https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/4.5.2/jna-platform-4.5.2.jar" -O "${BUILD_DIR}/lib/jna-platform.jar"
wget -nv "https://repo1.maven.org/maven2/io/pebbletemplates/pebble/3.1.5/pebble-3.1.5.jar" -O "${BUILD_DIR}/lib/pebble.jar"
wget -nv "https://repo1.maven.org/maven2/org/unbescape/unbescape/1.1.6.RELEASE/unbescape-1.1.6.RELEASE.jar" -O "${BUILD_DIR}/lib/unbescape.jar"
wget -nv "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar" -O "${BUILD_DIR}/lib/slf4j-api.jar"

echo "[3/7] Downloading Tanuki Wrapper..."
wget -nv "${TANUKI_URL}" -O "wrapper.tar.gz"
tar -xzf wrapper.tar.gz
SRC_W="wrapper-linux-x86-64-${WRAPPER_VER}"
cp "${SRC_W}/bin/wrapper" "${BUILD_DIR}/hyphanet-wrapper"
cp "${SRC_W}/lib/libwrapper.so" "${BUILD_DIR}/lib/libwrapper.so"
cp "${SRC_W}/lib/wrapper.jar" "${BUILD_DIR}/lib/wrapper.jar"
rm -rf "${SRC_W}" "wrapper.tar.gz"

echo "[4/7] Retrieving Seednodes..."
wget -nv "${SEEDS_URL}" -O "${BUILD_DIR}/seednodes.fref"

# 2. COPY LOCAL CONFIGURATION
echo "[5/7] Copying local wrapper.conf..."
cp "$LOCAL_CONF" "${BUILD_DIR}/wrapper.conf"

# 3. COPY LOCAL FREENET.INI (Headless Default)
echo "[6/7] Copying local freenet.ini..."
cp "$LOCAL_CONF" "${BUILD_DIR}/freenet.ini"

# 4. COPY LOCAL SERVICE LAUNCHER SCRIPT
echo "[7/7] Copying local freenet.ini..."
cp "$LOCAL_CONF" "${BUILD_DIR}/hyphanet-service"

chmod +x "${BUILD_DIR}/hyphanet-wrapper"
chmod +x "${BUILD_DIR}/hyphanet-service"

# ARCHIVING
echo "--- Creating archive in $RPM_SOURCES_DIR ---"
tar -czf "${RPM_SOURCES_DIR}/${ARCHIVE_NAME}" "${BUILD_DIR}"
echo "SUCCESS: Archive ready for rpmbuild."