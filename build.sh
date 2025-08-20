#!/bin/bash
set -euo pipefail

# This script automates the process of building the libra-setup Debian package.
# It downloads the required 'big-brother' binary and places it into the
# package structure before calling dpkg-deb.

# Source environment variables from .env file if it exists
if [ -f .env ]; then
  echo "--- Sourcing environment variables from .env file ---"
  set -a; source .env; set +a
else
  echo "--- No .env file found. Relying on exported environment variables. ---"
fi

# Check for GitHub token, which is required for downloading from private repos
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set." >&2
    echo "This is required to download release assets from private GitHub repositories." >&2
    echo "Please create a Personal Access Token with 'repo' scope and add it to a .env file." >&2
    echo "See: https://github.com/settings/tokens" >&2
    exit 1
fi

# Check for other required environment variables
REQUIRED_VARS=( "SYNC_REPO" "SYNC_VERSION" "SYNC_ASSET_NAME" "BIG_BROTHER_BINARY_URL" )
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "Error: Environment variable ${var} is not set." >&2
        echo "Please define it in your .env file or export it." >&2
        exit 1
    fi
done

# --- Github Asset Identification for 'sync' binary ---
# Get asset ID dynamically from the private repo
ASSET_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/${SYNC_REPO}/releases/tags/${SYNC_VERSION}" | \
  jq -r ".assets[] | select(.name==\"${SYNC_ASSET_NAME}\") | .id")

if [[ -z "${ASSET_ID}" || "${ASSET_ID}" == "null" ]]; then
  echo "Error: Could not find asset ID for '${SYNC_ASSET_NAME}' in release '${SYNC_VERSION}' of repo '${SYNC_REPO}'." >&2
  echo "Please check the SYNC_REPO, SYNC_VERSION, and SYNC_ASSET_NAME variables in your environment, and ensure the release and asset exist." >&2
  exit 1
fi

# --- Configuration ---
PACKAGE_DIR="libra-setup"
OUTPUT_DIR="output"
INSTALL_DIR="${PACKAGE_DIR}/usr/local/bin"
BIG_BROTHER_BINARY_NAME="big-brother"
BIG_BROTHER_TARGET_BINARY_PATH="${INSTALL_DIR}/${BIG_BROTHER_BINARY_NAME}"
SYNC_BINARY_URL="https://api.github.com/repos/${SYNC_REPO}/releases/assets/${ASSET_ID}"
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
mkdir -p "${OUTPUT_DIR}"

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
dpkg-deb --build --root-owner-group "${PACKAGE_DIR}" "${OUTPUT_DIR}/${PACKAGE_DIR}.deb"

echo -e "\n--- Build complete! ---"
echo "Package created: ${OUTPUT_DIR}/${PACKAGE_DIR}.deb"