#!/bin/bash
# =============================================================================
# Build and Push Docker Image to Docker Hub
# =============================================================================
# Usage:
#   ./build-and-push.sh                    # Build and push with version from .copilot-version
#   ./build-and-push.sh --no-push          # Build only, don't push
#   ./build-and-push.sh --platform amd64   # Build for specific platform only
# =============================================================================

set -e

# Configuration
DOCKER_HUB_REPO="${DOCKER_HUB_REPO:-henrybravo/docker-sandbox-run-copilot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/.copilot-version"

# Parse arguments
PUSH=true
PLATFORM="linux/amd64,linux/arm64"

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-push)
            PUSH=false
            shift
            ;;
        --platform)
            PLATFORM="linux/$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Read version from .copilot-version
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: .copilot-version file not found"
    exit 1
fi

COPILOT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
echo "Building with Copilot CLI version: $COPILOT_VERSION"

# Ensure buildx is available
if ! docker buildx version &>/dev/null; then
    echo "Error: Docker buildx is required for multi-platform builds"
    exit 1
fi

# Create/use buildx builder for multi-platform support
BUILDER_NAME="copilot-builder"
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo "Creating buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --use
else
    docker buildx use "$BUILDER_NAME"
fi

# Build tags
TAGS="-t ${DOCKER_HUB_REPO}:${COPILOT_VERSION} -t ${DOCKER_HUB_REPO}:latest"

echo "============================================="
echo "Building Docker image"
echo "  Repository: $DOCKER_HUB_REPO"
echo "  Version:    $COPILOT_VERSION"
echo "  Platforms:  $PLATFORM"
echo "  Push:       $PUSH"
echo "============================================="

# Build and optionally push
if [[ "$PUSH" == true ]]; then
    docker buildx build \
        --platform "$PLATFORM" \
        --build-arg COPILOT_VERSION="$COPILOT_VERSION" \
        $TAGS \
        --push \
        "$SCRIPT_DIR"

    echo "============================================="
    echo "Successfully built and pushed:"
    echo "  ${DOCKER_HUB_REPO}:${COPILOT_VERSION}"
    echo "  ${DOCKER_HUB_REPO}:latest"
    echo "============================================="
else
    # For local build without push, we need to load to local docker
    # This only works with single platform
    if [[ "$PLATFORM" == *","* ]]; then
        echo "Warning: Multi-platform builds without push cannot be loaded locally."
        echo "         Building for linux/amd64 only for local use."
        PLATFORM="linux/amd64"
    fi

    docker buildx build \
        --platform "$PLATFORM" \
        --build-arg COPILOT_VERSION="$COPILOT_VERSION" \
        $TAGS \
        --load \
        "$SCRIPT_DIR"

    echo "============================================="
    echo "Successfully built (local only):"
    echo "  ${DOCKER_HUB_REPO}:${COPILOT_VERSION}"
    echo "  ${DOCKER_HUB_REPO}:latest"
    echo "============================================="
fi
