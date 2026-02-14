#!/bin/bash
# Hyphanet Source Preparation Script for RPM packaging
set -e

VERSION="0.7.1505"
BUILD_ID="01505"
BUILD_DIR="fred-build${BUILD_ID}"
ARCHIVE_NAME="hyphanet-${VERSION}.tar.gz"
RPM_SOURCES_DIR="$HOME/rpmbuild/SOURCES"

INSTALL_PATH="/opt/hyphanet"      # Static binaries
DATA_PATH="/var/lib/hyphanet"     # Dynamic data (datastore, configs)
LOG_PATH="/var/log/hyphanet"      # Logs

WRAPPER_VER="3.5.51"
TANUKI_URL="https://download.tanukisoftware.com/wrapper/${WRAPPER_VER}/wrapper-linux-x86-64-${WRAPPER_VER}.tar.gz"
CONFIG_URL="https://raw.githubusercontent.com/hyphanet/java_installer/master/res/wrapper.conf"
SEEDS_URL="https://raw.githubusercontent.com/hyphanet/java_installer/refs/heads/next/offline/seednodes.fref"

# JAR Dependency List
declare -A JARS
JARS=(
    ["bcprov.jar"]="https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk15on/1.59/bcprov-jdk15on-1.59.jar"
    ["jna.jar"]="https://repo1.maven.org/maven2/net/java/dev/jna/jna/4.5.2/jna-4.5.2.jar"
    ["jna-platform.jar"]="https://repo1.maven.org/maven2/net/java/dev/jna/jna-platform/4.5.2/jna-platform-4.5.2.jar"
    ["pebble.jar"]="https://repo1.maven.org/maven2/io/pebbletemplates/pebble/3.1.5/pebble-3.1.5.jar"
    ["unbescape.jar"]="https://repo1.maven.org/maven2/org/unbescape/unbescape/1.1.6.RELEASE/unbescape-1.1.6.RELEASE.jar"
    ["slf4j-api.jar"]="https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar"
)

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

# 2. WRAPPER CONFIGURATION
echo "[5/7] Configuring wrapper.conf..."
wget -nv "${CONFIG_URL}" -O "${BUILD_DIR}/wrapper.conf"
CONF="${BUILD_DIR}/wrapper.conf"

# Set TODO : remove this hacks if possible
sed -i "s|wrapper.java.classpath.1=.*|wrapper.java.classpath.1=${INSTALL_PATH}/lib/wrapper.jar|" "$CONF"
sed -i "s|wrapper.java.classpath.2=.*|wrapper.java.classpath.2=${INSTALL_PATH}/freenet.jar|" "$CONF"
sed -i "s|wrapper.java.classpath.3=.*|wrapper.java.classpath.3=${INSTALL_PATH}/lib/freenet-ext.jar|" "$CONF"

# add the other JARs
echo "wrapper.java.classpath.4=${INSTALL_PATH}/lib/bcprov.jar" >> "$CONF"
echo "wrapper.java.classpath.5=${INSTALL_PATH}/lib/jna.jar" >> "$CONF"
echo "wrapper.java.classpath.6=${INSTALL_PATH}/lib/jna-platform.jar" >> "$CONF"
echo "wrapper.java.classpath.7=${INSTALL_PATH}/lib/pebble.jar" >> "$CONF"
echo "wrapper.java.classpath.8=${INSTALL_PATH}/lib/unbescape.jar" >> "$CONF"
echo "wrapper.java.classpath.9=${INSTALL_PATH}/lib/slf4j-api.jar" >> "$CONF"

# TODO: remove this hacks if possible
sed -i "s|wrapper.java.library.path.1=.*|wrapper.java.library.path.1=${INSTALL_PATH}/lib|" "$CONF"
sed -i "s|wrapper.logfile=.*|wrapper.logfile=${LOG_PATH}/wrapper.log|" "$CONF"

# TODO: remove this hacks if possible
# Force the working directory to /var/lib/hyphanet (where the user has write permissions)
if ! grep -q "wrapper.working.dir" "$CONF"; then echo "wrapper.working.dir=${DATA_PATH}" >> "$CONF"; else sed -i "s|wrapper.working.dir=.*|wrapper.working.dir=${DATA_PATH}|" "$CONF"; fi
# Move Lock/PID files to /var/lib
if ! grep -q "wrapper.anchorfile" "$CONF"; then echo "wrapper.anchorfile=${DATA_PATH}/hyphanet.anchor" >> "$CONF"; else sed -i "s|wrapper.anchorfile=.*|wrapper.anchorfile=${DATA_PATH}/hyphanet.anchor|" "$CONF"; fi
if ! grep -q "wrapper.pidfile" "$CONF"; then echo "wrapper.pidfile=${DATA_PATH}/hyphanet.pid" >> "$CONF"; else sed -i "s|wrapper.pidfile=.*|wrapper.pidfile=${DATA_PATH}/hyphanet.pid|" "$CONF"; fi
# Force UTF-8 encoding
if ! grep -q "wrapper.console.encoding" "$CONF"; then echo "wrapper.console.encoding=UTF-8" >> "$CONF"; fi

# 3. GENERATING FREENET.INI TODO: using a file
echo "[6/7] Generating freenet.ini (Headless configuration)..."

cat <<EOF > "${BUILD_DIR}/freenet.ini"
# Disable auto-updater (Managed by RPM/Package Manager)
node.updater.enabled=false
# Enable Opennet by default for immediate connectivity
node.opennet.enabled=true
node.name=Hyphanet-Node
# Paths relative to wrapper.working.dir (/var/lib/hyphanet)
node.install.userDir=.
node.tempDir=temp
# FProxy Configuration (WebUI)
fproxy.enabled=true
fproxy.port=8888
fproxy.bindTo=127.0.0.1
# Logging
logger.priority=ERROR
logger.dirname=logs
# Default Bandwidth Limits (4MB/s)
node.outputBandwidthLimit=4M
node.inputBandwidthLimit=4M
# Load plugins required for basic operation (preventing headless startup hang)
pluginmanager.loadplugin=JSTUN;KeyUtils;ThawIndexBrowser
EOF

chmod 644 "${BUILD_DIR}/freenet.ini"

# 4. SERVICE LAUNCHER SCRIPT TODO: using a file
echo "[7/7] Creating service launcher script..."
cat <<EOS > "${BUILD_DIR}/hyphanet-service"
#!/bin/bash
# Wrapper Launcher Helper
WRAPPER_CMD="${INSTALL_PATH}/hyphanet-wrapper"
CONF_FILE="${INSTALL_PATH}/wrapper.conf"
PID_FILE="${DATA_PATH}/hyphanet.pid"

case "\$1" in
    'start')
        # Daemon Mode (Systemd)
        exec "\$WRAPPER_CMD" "\$CONF_FILE" wrapper.pidfile="\$PID_FILE" wrapper.daemonize=TRUE
        ;;
    'console')
        # Console Mode (Manual Debugging)
        exec "\$WRAPPER_CMD" "\$CONF_FILE" wrapper.pidfile="\$PID_FILE" wrapper.daemonize=FALSE
        ;;
    *)
        echo "Usage: \$0 {start|console}"; exit 1
        ;;
esac
EOS

chmod +x "${BUILD_DIR}/hyphanet-wrapper"
chmod +x "${BUILD_DIR}/hyphanet-service"

# ARCHIVING
echo "--- Creating archive in $RPM_SOURCES_DIR ---"
tar -czf "${RPM_SOURCES_DIR}/${ARCHIVE_NAME}" "${BUILD_DIR}"
echo "SUCCESS: Archive ready for rpmbuild. Use rpmbuild -ba SPECS/hyphanet.spec to build the rpm"