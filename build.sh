#!/bin/bash
set -euo pipefail

# This script automates the process of building the libra-setup Debian package.
# It downloads the required 'big-brother' binary and places it into the
# package structure before calling dpkg-deb.

# --- Configuration ---
PACKAGE_DIR="libra-setup"
INSTALL_DIR="${PACKAGE_DIR}/usr/local/bin"
BIG_BROTHER_BINARY_URL="https://github.com/rileyhernandez/big_brother/releases/download/v0.0.4/big-brother-arm64"
BIG_BROTHER_BINARY_NAME="big-brother"
BIG_BROTHER_TARGET_BINARY_PATH="${INSTALL_DIR}/${BIG_BROTHER_BINARY_NAME}"
SYNC_BINARY_URL="https://github.com/Caldo-Restaurant-Technologies/sync/releases/download/v0.0.0/sync_0.0-0_arm64"
SYNC_BINARY_NAME="sync"
SYNC_TARGET_BINARY_PATH="${INSTALL_DIR}/${SYNC_BINARY_NAME}"


# --- Build Process ---

# Check for required build tools
if ! command -v curl &> /dev/null || ! command -v dpkg-deb &> /dev/null; then
    echo "Error: Missing required build tools." >&2
    echo "Please ensure 'curl' and 'dpkg-dev' are installed." >&2
    echo "On Debian/Ubuntu, run: sudo apt-get install -y curl dpkg-dev" >&2
    exit 1
fi

# Ensure the script is run from the project's root directory
if [ ! -d "$PACKAGE_DIR/DEBIAN" ]; then
    echo "Error: Please run this script from the parent directory of '${PACKAGE_DIR}'."
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "--- Preparing package structure ---"
mkdir -p "${INSTALL_DIR}"

# big brother install
echo "--- Downloading big-brother binary from ${BIG_BROTHER_BINARY_URL} ---"
curl -LfsS "${BIG_BROTHER_BINARY_URL}" -o "${BIG_BROTHER_TARGET_BINARY_PATH}"

# sync install
ech "--- Downloading sync binary from ${SYNC_BINARY_URL} ---"
curl -LfsS "${SYNC_BINARY_URL}" -o "${SYNC_TARGET_BINARY_PATH}"

echo "--- Setting binary permissions ---"
chmod +x "${BIG_BROTHER_TARGET_BINARY_PATH}"
chmod +x "${SYNC_TARGET_BINARY_PATH}"


echo "--- Building Debian package ---"
dpkg-deb --build "${PACKAGE_DIR}"

echo -e "\n--- Build complete! ---"
echo "Package created: ${PACKAGE_DIR}.deb"