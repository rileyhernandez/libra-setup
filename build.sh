#!/bin/bash
set -euo pipefail

# This script automates the process of building the libra-setup Debian package.
# It downloads the required 'big-brother' binary and places it into the
# package structure before calling dpkg-deb.

# --- Configuration ---
PACKAGE_DIR="libra-setup"
BINARY_URL="https://github.com/rileyhernandez/big_brother/releases/download/v0.0.4/big-brother-arm64"
INSTALL_DIR="${PACKAGE_DIR}/usr/local/bin"
BINARY_NAME="big-brother"
TARGET_BINARY_PATH="${INSTALL_DIR}/${BINARY_NAME}"

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

echo "--- Downloading big-brother binary from ${BINARY_URL} ---"
curl -LfsS "${BINARY_URL}" -o "${TARGET_BINARY_PATH}"

echo "--- Setting binary permissions ---"
chmod +x "${TARGET_BINARY_PATH}"

echo "--- Building Debian package ---"
dpkg-deb --build "${PACKAGE_DIR}"

echo -e "\n--- Build complete! ---"
echo "Package created: ${PACKAGE_DIR}.deb"