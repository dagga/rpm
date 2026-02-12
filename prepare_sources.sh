#!/bin/bash
VERSION="0.7.1505"
BUILD_ID="01505"
BUILD_DIR="fred-build${BUILD_ID}"
ARCHIVE_NAME="hyphanet-${VERSION}.tar.gz"

# Version Wrapper Tanuki
WRAPPER_VER="3.5.51"
TANUKI_URL="https://download.tanukisoftware.com/wrapper/${WRAPPER_VER}/wrapper-linux-x86-64-${WRAPPER_VER}.tar.gz"

# URL Config (Celle que vous avez validée précédemment)
CONFIG_URL="https://raw.githubusercontent.com/hyphanet/java_installer/master/res/wrapper.conf"

echo "--- Préparation Hyphanet ${VERSION} (Extraction Interne) ---"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/lib"

# 1. TÉLÉCHARGEMENT FREENET (Base)
echo "[1/5] Téléchargement Freenet..."
wget -q "https://github.com/hyphanet/fred/releases/download/build${BUILD_ID}/freenet.jar" -O "${BUILD_DIR}/freenet.jar"
wget -q "https://github.com/hyphanet/fred/releases/download/build${BUILD_ID}/freenet-ext.jar" -O "${BUILD_DIR}/lib/freenet-ext.jar"

if [ ! -s "${BUILD_DIR}/freenet.jar" ]; then echo "ERREUR: freenet.jar manquant"; exit 1; fi

# 2. TÉLÉCHARGEMENT WRAPPER (Tanuki)
echo "[2/5] Intégration Wrapper Tanuki..."
wget -q "${TANUKI_URL}" -O "wrapper.tar.gz"
if [ ! -s "wrapper.tar.gz" ]; then echo "ERREUR: Tanuki inaccessible"; exit 1; fi

tar -xzf wrapper.tar.gz
SRC_W="wrapper-linux-x86-64-${WRAPPER_VER}"

cp "${SRC_W}/bin/wrapper" "${BUILD_DIR}/hyphanet-wrapper"
cp "${SRC_W}/lib/libwrapper.so" "${BUILD_DIR}/lib/libwrapper.so"
cp "${SRC_W}/lib/wrapper.jar" "${BUILD_DIR}/lib/wrapper.jar"
rm -rf "${SRC_W}" "wrapper.tar.gz"

# 3. CONFIGURATION
echo "[3/5] Récupération wrapper.conf..."
wget -q "${CONFIG_URL}" -O "${BUILD_DIR}/wrapper.conf"

if [ ! -s "${BUILD_DIR}/wrapper.conf" ]; then
    echo "ERREUR: Impossible de télécharger wrapper.conf depuis java_installer."
    exit 1
fi

# 4. TELECHARGEMENT DES SEEDNODES

echo "[4/5] Tétéléchargement depuis raw.githubusercontent.com/hyphanet/java_installer/"
echo "   > Tentative téléchargement depuis hyphanet/java_installer/refs/heads/next/offline/"
wget -q "https://raw.githubusercontent.com/hyphanet/java_installer/refs/heads/next/offline/seednodes.fref" -O "${BUILD_DIR}/seednodes.fref"

# 5. ADAPTATION CONFIGURATION & SCRIPTS
echo "[5/5] Finalisation..."

# Patch des chemins wrapper.conf
sed -i 's|wrapper.java.classpath.1=.*|wrapper.java.classpath.1=lib/wrapper.jar|' "${BUILD_DIR}/wrapper.conf"
sed -i 's|wrapper.java.classpath.2=.*|wrapper.java.classpath.2=freenet.jar|' "${BUILD_DIR}/wrapper.conf"
sed -i 's|wrapper.java.classpath.3=.*|wrapper.java.classpath.3=lib/freenet-ext.jar|' "${BUILD_DIR}/wrapper.conf"
sed -i 's|wrapper.java.library.path.1=.*|wrapper.java.library.path.1=lib|' "${BUILD_DIR}/wrapper.conf"

# Encodage UTF-8
if ! grep -q "wrapper.console.encoding" "${BUILD_DIR}/wrapper.conf"; then
    echo "wrapper.console.encoding=UTF-8" >> "${BUILD_DIR}/wrapper.conf"
fi

# Fichier hyphanet.conf
cat <<EOF > "${BUILD_DIR}/hyphanet.conf"
node.updater.enabled=false
node.install.user=hyphanet
node.name=Hyphanet-Node-RPM
EOF

# Script hyphanet-service
cat <<EOS > "${BUILD_DIR}/hyphanet-service"
#!/bin/bash
APP_NAME="hyphanet"
PID_FILE="hyphanet.pid"
./hyphanet-wrapper wrapper.conf wrapper.pidfile=\$PID_FILE wrapper.daemonize=TRUE
EOS

chmod +x "${BUILD_DIR}/hyphanet-wrapper"
chmod +x "${BUILD_DIR}/hyphanet-service"

# Archivage
tar -czf "${ARCHIVE_NAME}" "${BUILD_DIR}"

echo "---"
echo "Succès ! Archive ${ARCHIVE_NAME} prête."
