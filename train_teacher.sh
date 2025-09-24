#!/bin/bash

# Optimized teacher policy training script - reduces Docker overhead

# Parse command line arguments
REBUILD=false
TRAINING_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        *)
            # Pass all other arguments to the training script
            TRAINING_ARGS="$TRAINING_ARGS $1"
            shift
            ;;
    esac
done

# Set default training arguments if none provided
if [ -z "$TRAINING_ARGS" ]; then
    TRAINING_ARGS="--num_envs 1024 --headless"
fi

echo "Starting optimized teacher policy training..."
echo "Training arguments: $TRAINING_ARGS"

# Build the optimized container if --rebuild flag is set
echo "Building optimized Docker container..."
docker build -f Dockerfile_Optimized -t hover:optimized .
if [ $? -ne 0 ]; then
    echo "Error: Failed to build Docker container"
        exit 1
fi

# Check if the optimized image exists
if ! docker image inspect hover:optimized > /dev/null 2>&1; then
    echo "Optimized Docker image not found. Building it now..."
    docker build -f Dockerfile_Optimized -t hover:optimized .
    if [ $? -ne 0 ]; then
        echo "Error: Failed to build Docker container"
        exit 1
    fi
fi

# Run the optimized container
echo "Running optimized teacher policy training..."

# Check if a container with the same name is already running and remove it
if docker ps -a --format "table {{.Names}}" | grep -q "^hover_teacher$"; then
    echo "Removing existing container 'hover_teacher'..."
    docker rm -f hover_teacher
fi

echo "starting container..."
docker run -it --rm \
    --runtime=nvidia --gpus all \
    --shm-size=8g \
    --entrypoint /workspace/isaaclab/isaaclab.sh \
    -e "ACCEPT_EULA=Y" \
    -e "PYTHONUNBUFFERED=1" \
    -e "PYTHONIOENCODING=utf-8" \
    -v $(pwd):/workspace/neural_wbc \
    --name hover_teacher \
    hover:optimized \
    -p scripts/rsl_rl/train_teacher_policy.py $TRAINING_ARGS
