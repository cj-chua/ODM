#!/bin/bash
set -e

TARGET_DIR="/runpod-volume"
LINK_NAME="/datasets"

echo "Runpod Entrypoint: Ensuring symlink for network storage..."

# Check if the target directory exists (where Runpod mounts the volume)
if [ -d "$TARGET_DIR" ]; then
    # Check if the symlink already exists and points correctly
    if [ ! -L "$LINK_NAME" ] || [ "$(readlink -f "$LINK_NAME")" != "$TARGET_DIR" ]; then
        # If /datasets exists but isn't a correct symlink to /runpod-volume (e.g., it's a directory or a broken link)
        if [ -e "$LINK_NAME" ]; then
            echo "Removing existing $LINK_NAME (it's not a correct symlink to $TARGET_DIR or it's a directory)..."
            rm -rf "$LINK_NAME" # Aggressively remove if it's not our symlink
        fi
        echo "Creating symlink: $LINK_NAME -> $TARGET_DIR"
        ln -s "$TARGET_DIR" "$LINK_NAME"
    else
        echo "Symlink $LINK_NAME already points to $TARGET_DIR. All good."
    fi
else
    echo "WARNING: $TARGET_DIR (Runpod volume mount point) not found. This might indicate an issue with Runpod's volume mounting or that this container is not running on Runpod with network storage."
    echo "ODM will likely fail if it expects data at $LINK_NAME and no link could be created."
fi

echo "Runpod Entrypoint: No specific command arguments provided to the container."
exec python3 /code/run.py --project-path /datasets .
