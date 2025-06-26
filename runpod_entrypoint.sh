#!/bin/bash
set -e

TARGET_DIR="/runpod-volume"
LINK_NAME="/datasets"
DEFAULT_PROJECT_NAME="project"

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

# Determine the command to execute
# The original ODM command is `python3 /code/run.py [args...]`
# Our entrypoint will now be responsible for calling `python3 /code/run.py`.
# If arguments are provided to our entrypoint (via Docker's CMD or run arguments),
# we pass them directly to `run.py`.
# If no arguments are provided (common in serverless platforms where CMD is often empty),
# we construct a default command.

if [ "$#" -eq 0 ]; then
    echo "Runpod Entrypoint: No specific command arguments provided to the container."
    echo "Defaulting to ODM processing for project: $DEFAULT_PROJECT_NAME, using --project-path $LINK_NAME."
    # Default command when nothing is passed to the container:
    # `python3 /code/run.py --project-path /datasets runpod_default_project`
    exec python3 /code/run.py --project-path "$LINK_NAME" "$DEFAULT_PROJECT_NAME"
else
    echo "Runpod Entrypoint: Executing python3 /code/run.py with arguments: $*"
    # Execute `python3 /code/run.py` with any arguments passed to our entrypoint.
    # This allows for more specific ODM commands if Runpod Serverless allows them,
    # or for local testing with custom commands.
    exec python3 /code/run.py "$@"
fi
