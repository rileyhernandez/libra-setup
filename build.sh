#!/bin/bash
set -euo pipefail

# This script automates the process of building the libra-setup Debian package.
# It downloads the required 'big-brother' binary and places it into the
# package structure before calling dpkg-deb.

# --- Github Asset Identification
REPO="Caldo-Restaurant-Technologies/sync"
VERSION="v0.0.0"
ASSET_NAME="sync_0.0-0_arm64"

# Get asset ID dynamically
ASSET_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/${REPO}/releases/tags/${VERSION}" | \
  jq -r ".assets[] | select(.name==\"${ASSET_NAME}\") | .id")

# --- Configuration ---
PACKAGE_DIR="libra-setup"
INSTALL_DIR="${PACKAGE_DIR}/usr/local/bin"
BIG_BROTHER_BINARY_URL="https://github.com/rileyhernandez/big_brother/releases/download/v0.0.4/big-brother-arm64"
BIG_BROTHER_BINARY_NAME="big-brother"
BIG_BROTHER_TARGET_BINARY_PATH="${INSTALL_DIR}/${BIG_BROTHER_BINARY_NAME}"
SYNC_BINARY_URL="https://api.github.com/repos/${REPO}/releases/assets/${ASSET_ID}"
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

 # Check for GitHub token, which is required for downloading from private repos
 if [ -z "${GITHUB_TOKEN:-}" ]; then
     echo "Error: GITHUB_TOKEN environment variable is not set." >&2
     echo "This is required to download release assets from private GitHub repositories." >&2
     echo "Please create a Personal Access Token with 'repo' scope and export it:" >&2
     echo "export GITHUB_TOKEN=\"your_token_here\"" >&2
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
echo "--- Downloading sync binary from ${SYNC_BINARY_URL} ---"
curl -LfsS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/octet-stream" \
  "${SYNC_BINARY_URL}" -o "${SYNC_TARGET_BINARY_PATH}"

echo "--- Setting binary permissions ---"
chmod +x "${BIG_BROTHER_TARGET_BINARY_PATH}"
chmod +x "${SYNC_TARGET_BINARY_PATH}"


echo "--- Building Debian package ---"
dpkg-deb --build "${PACKAGE_DIR}"

echo -e "\n--- Build complete! ---"
echo "Package created: ${PACKAGE_DIR}.deb"