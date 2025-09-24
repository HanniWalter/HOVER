#!/bin/bash
#
# SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

echo "Docker optimized install script - initializing git repository and submodules..."

# Install git if not available
apt-get update && apt-get install -y git || true

# Initialize git repository if not exists
if [ ! -d .git ]; then
    echo "Initializing git repository..."
    git init
    git remote add origin https://github.com/HanniWalter/HOVER.git || true
fi

# Initialize and update submodules manually
echo "Installing git submodules manually..."
if [ ! -d "third_party/human2humanoid/.git" ]; then
    echo "Cloning human2humanoid submodule..."
    rm -rf third_party/human2humanoid
    git clone https://github.com/ZhengyiLuo/PHC.git third_party/human2humanoid
fi

if [ ! -d "third_party/mujoco_viewer/.git" ]; then
    echo "Cloning mujoco_viewer submodule..."
    rm -rf third_party/mujoco_viewer
    git clone https://github.com/rohanpsingh/mujoco-python-viewer.git third_party/mujoco_viewer
fi

if [ ! -d "third_party/rsl_rl/.git" ]; then
    echo "Cloning rsl_rl submodule..."
    rm -rf third_party/rsl_rl
    git clone https://github.com/leggedrobotics/rsl_rl.git third_party/rsl_rl
fi

echo "Resetting changes in third_party/human2humanoid..."
pushd third_party/human2humanoid || exit 1
git reset --hard || true
popd

# Apply patch to files - check if already patched first
if [ -f third_party/human2humanoid/phc/phc/utils/torch_utils.py ]; then
    if grep -q "# PATCH APPLIED" third_party/human2humanoid/phc/phc/utils/torch_utils.py; then
        echo "Patch already applied, skipping..."
    else
        if patch --dry-run --silent -f third_party/human2humanoid/phc/phc/utils/torch_utils.py < third_party/phc_torch_utils.patch; then
            echo "Dry run succeeded. Applying the patch..."
            patch third_party/human2humanoid/phc/phc/utils/torch_utils.py < third_party/phc_torch_utils.patch
            echo "# PATCH APPLIED" >> third_party/human2humanoid/phc/phc/utils/torch_utils.py
            echo "Patch applied successfully."
        else
            echo "Patch dry run failed, but continuing in Docker environment..."
            # In Docker we might have pre-patched files, so continue
        fi
    fi
else
    echo "Warning: torch_utils.py not found, continuing anyway..."
fi

# Install libraries.
${ISAACLAB_PATH:?}/isaaclab.sh -p -m ensurepip
${ISAACLAB_PATH:?}/isaaclab.sh -p -m pip install --upgrade pip
${ISAACLAB_PATH:?}/isaaclab.sh -p -m pip install wheel
${ISAACLAB_PATH:?}/isaaclab.sh -p -m pip install -e .

# Create a filtered requirements.txt with all dependencies including submodules
echo "Creating filtered requirements.txt for Docker..."
cat > requirements_docker.txt << EOF
joblib>=1.2.0
wheel
git+https://github.com/ZhengyiLuo/SMPLSim.git@dd65a86
easydict
warp-lang
dataclass-wizard

-e neural_wbc/core
-e neural_wbc/data
-e neural_wbc/isaac_lab_wrapper
-e neural_wbc/mujoco_wrapper
-e neural_wbc/inference_env
-e neural_wbc/student_policy
-e third_party/mujoco_viewer
-e third_party/rsl_rl
EOF

# Install only existing dependencies
${ISAACLAB_PATH:?}/isaaclab.sh -p -m pip install -r requirements_docker.txt

echo "Dependencies installed successfully in Docker environment."
