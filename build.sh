#!/bin/bash
set -euo pipefail

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
REQUIRED_VARS=( "SYNC_REPO" "SYNC_VERSION" "SYNC_ASSET_NAME" "LIBRA_INVENTORY_BINARY_URL" "UPDATE_REPO" "UPDATE_VERSION" "UPDATE_ASSET_NAME" )
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "Error: Environment variable ${var} is not set." >&2
        echo "Please define it in your .env file or export it." >&2
        exit 1
    fi
done

# --- Github Asset Identification for 'sync' and 'libra-update' binaries ---
# Get asset ID dynamically from the private repo
SYNC_ASSET_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/${SYNC_REPO}/releases/tags/${SYNC_VERSION}" | \
  jq -r ".assets[] | select(.name==\"${SYNC_ASSET_NAME}\") | .id")

if [[ -z "${SYNC_ASSET_ID}" || "${SYNC_ASSET_ID}" == "null" ]]; then
  echo "Error: Could not find asset ID for '${SYNC_ASSET_NAME}' in release '${SYNC_VERSION}' of repo '${SYNC_REPO}'." >&2
  echo "Please check the SYNC_REPO, SYNC_VERSION, and SYNC_ASSET_NAME variables in your environment, and ensure the release and asset exist." >&2
  exit 1
fi

# Get asset ID dynamically from the private repo
UPDATE_ASSET_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/${UPDATE_REPO}/releases/tags/${UPDATE_VERSION}" | \
  jq -r ".assets[] | select(.name==\"${UPDATE_ASSET_NAME}\") | .id")

if [[ -z "${UPDATE_ASSET_ID}" || "${UPDATE_ASSET_ID}" == "null" ]]; then
  echo "Error: Could not find asset ID for '${UDPATE_ASSET_NAME}' in release '${UPDATE_VERSION}' of repo '${UPDATE_REPO}'." >&2
  echo "Please check the UPDATE_REPO, UPDATE_VERSION, and UPDATE_ASSET_NAME variables in your environment, and ensure the release and asset exist." >&2
  exit 1
fi

# --- Configuration ---
PACKAGE_DIR="libra-setup"
OUTPUT_DIR="output"
INSTALL_DIR="${PACKAGE_DIR}/usr/local/bin"
LIBRA_INVENTORY_BINARY_NAME="libra-inventory"
LIBRA_INVENTORY_TARGET_BINARY_PATH="${INSTALL_DIR}/${LIBRA_INVENTORY_BINARY_NAME}"
SYNC_BINARY_URL="https://api.github.com/repos/${SYNC_REPO}/releases/assets/${SYNC_ASSET_ID}"
SYNC_BINARY_NAME="sync"
SYNC_TARGET_BINARY_PATH="${INSTALL_DIR}/${SYNC_BINARY_NAME}"
UPDATE_BINARY_URL="https://api.github.com/repos/${UPDATE_REPO}/releases/assets/${UPDATE_ASSET_ID}"
UPDATE_BINARY_NAME="libra-update"
UPDATE_TARGET_BINARY_PATH="${INSTALL_DIR}/${UPDATE_BINARY_NAME}"


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

# libra inventory install
echo "--- Downloading libra-inventory binary from ${LIBRA_INVENTORY_BINARY_URL} ---"
curl -LfsS "${LIBRA_INVENTORY_BINARY_URL}" -o "${LIBRA_INVENTORY_TARGET_BINARY_PATH}"

# sync install
echo "--- Downloading sync binary from ${SYNC_BINARY_URL} ---"
curl -LfsS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/octet-stream" \
  "${SYNC_BINARY_URL}" -o "${SYNC_TARGET_BINARY_PATH}"

# update install
echo "--- Downloading libra-update binary from ${UPDATE_BINARY_URL} ---"
curl -LfsS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/octet-stream" \
  "${UPDATE_BINARY_URL}" -o "${UPDATE_TARGET_BINARY_PATH}"

echo "--- Setting binary permissions ---"
chmod +x "${LIBRA_INVENTORY_TARGET_BINARY_PATH}"
chmod +x "${SYNC_TARGET_BINARY_PATH}"
chmod +x "${UPDATE_TARGET_BINARY_PATH}"


echo "--- Building Debian package ---"
dpkg-deb --build --root-owner-group "${PACKAGE_DIR}" "${OUTPUT_DIR}/${PACKAGE_DIR}.deb"

echo -e "\n--- Build complete! ---"
echo "Package created: ${OUTPUT_DIR}/${PACKAGE_DIR}.deb"