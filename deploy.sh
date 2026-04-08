#!/bin/bash
# deploy.sh -- Deploy agent-browser-vnc source to Unraid and rebuild container
#
# Usage:
#   bash D:/infrastructure/projects/agent-browser-vnc/deploy.sh              # deploy + rebuild
#   bash D:/infrastructure/projects/agent-browser-vnc/deploy.sh --dry-run    # show what would be deployed
#   bash D:/infrastructure/projects/agent-browser-vnc/deploy.sh --no-build   # deploy files only, skip rebuild

set -euo pipefail

REMOTE="root@nas.lab.idka.info"
BUILD_DIR="/mnt/user/appdata/agent-browser-vnc/build"
COMPOSE_DIR="/boot/config/plugins/compose.manager/projects/agent-browser-vnc"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
NO_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --no-build) NO_BUILD=true; shift ;;
        *)          echo "Unknown arg: $1"; exit 1 ;;
    esac
done

echo "=== agent-browser-vnc deploy ==="

if $DRY_RUN; then
    echo "Would deploy to $REMOTE:$BUILD_DIR/"
    echo "  Dockerfile"
    echo "  rootfs/ (directory)"
    echo "Would deploy to $REMOTE:$COMPOSE_DIR/"
    echo "  docker-compose.yml"
    echo "=== Deploy complete (dry run) ==="
    exit 0
fi

echo "Deploying source to $BUILD_DIR/"
# shellcheck disable=SC2029
ssh "$REMOTE" "mkdir -p $BUILD_DIR"
scp -q "$SCRIPT_DIR/Dockerfile" "$REMOTE:$BUILD_DIR/" && echo "  OK: Dockerfile"
scp -qr "$SCRIPT_DIR/rootfs" "$REMOTE:$BUILD_DIR/" && echo "  OK: rootfs/"

echo "Deploying docker-compose.yml to $COMPOSE_DIR/"
# shellcheck disable=SC2029
ssh "$REMOTE" "mkdir -p $COMPOSE_DIR"
scp -q "$SCRIPT_DIR/docker-compose.yml" "$REMOTE:$COMPOSE_DIR/" && echo "  OK: docker-compose.yml"

if $NO_BUILD; then
    echo "=== Deploy complete (no build) ==="
    exit 0
fi

echo "Building image..."
# shellcheck disable=SC2029
ssh "$REMOTE" "cd $BUILD_DIR && docker build -t agent-browser-vnc:local . 2>&1 | tail -5"

echo "Restarting container..."
# shellcheck disable=SC2029
ssh "$REMOTE" "cd $COMPOSE_DIR && docker compose up -d agent-browser-vnc 2>&1"

echo "=== Deploy complete ==="
