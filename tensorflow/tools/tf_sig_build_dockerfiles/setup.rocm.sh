#!/usr/bin/env bash
#
# Copyright 2022 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
#
# setup.rocm.sh: Prepare the ROCM installation on the container.
# Usage: setup.rocm.sh <ROCM_VERSION>
set -x

# Add the ROCm package repo location
ROCM_VERSION=$1 # e.g. 5.2.0
ROCM_PATH=${ROCM_PATH:-/opt/rocm-${ROCM_VERSION}}
ROCM_DEB_REPO_HOME=https://repo.radeon.com/rocm/apt/
AMDGPU_DEB_REPO_HOME=https://repo.radeon.com/amdgpu/
ROCM_BUILD_NAME=ubuntu
ROCM_BUILD_NUM=main

# Adjust the ROCM repo location
# Intial release don't have the trialing '.0'
# For example ROCM 5.4.0 is at https://repo.radeon.com/rocm/apt/5.4/
if [ ${ROCM_VERSION##*[^0-9]} -eq '0' ]; then
        ROCM_VERS=${ROCM_VERSION%.*}
else
        ROCM_VERS=$ROCM_VERSION
fi
ROCM_DEB_REPO=${ROCM_DEB_REPO_HOME}${ROCM_VERS}/
AMDGPU_DEB_REPO=${AMDGPU_DEB_REPO_HOME}${ROCM_VERS}/

DEBIAN_FRONTEND=noninteractive apt-get --allow-unauthenticated update 
DEBIAN_FRONTEND=noninteractive apt install -y wget software-properties-common
DEBIAN_FRONTEND=noninteractive apt-get clean all

if [ ! -f "/${CUSTOM_INSTALL}" ]; then
# Add rocm repository
chmod 1777 /tmp
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -;
if [[ $ROCM_DEB_REPO == https://repo.radeon.com/rocm/*  ]] ; then \
      echo "deb [arch=amd64] $ROCM_DEB_REPO $ROCM_BUILD_NAME $ROCM_BUILD_NUM" > /etc/apt/sources.list.d/rocm.list; \
      echo "deb [arch=amd64] $AMDGPU_DEB_REPO$ROCM_BUILD_NAME focal $ROCM_BUILD_NUM" > /etc/apt/sources.list.d/amdgpu.list; \
    else \
      echo "deb [arch=amd64 trusted=yes] $ROCM_DEB_REPO $ROCM_BUILD_NAME $ROCM_BUILD_NUM" > /etc/apt/sources.list.d/rocm.list ; \
    fi
else
    bash "/${CUSTOM_INSTALL}"
fi

wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -;
echo "deb [arch=amd64 trusted=yes] http://apt.llvm.org/focal/ llvm-toolchain-focal-17 main" > /etc/apt/sources.list.d/llvm.list

GPU_DEVICE_TARGETS=${GPU_DEVICE_TARGETS:-"gfx900 gfx906 gfx908 gfx90a gfx940 gfx941 gfx942 gfx1030 gfx1031 gfx1100"}

echo $ROCM_VERSION
echo $ROCM_REPO
echo $ROCM_PATH
echo $GPU_DEVICE_TARGETS

# install rocm
/setup.packages.sh /devel.packages.rocm.txt

apt-get update --allow-insecure-repositories
MIOPENKERNELS=$( \
                    apt-cache search --names-only miopen-hip-gfx | \
                    awk '{print $1}' | \
                    grep -F -v . || \
		    true )
DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated ${MIOPENKERNELS}

#install hipblasLT if available
DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated hipblaslt-dev || true

# Ensure the ROCm target list is set up
printf '%s\n' ${GPU_DEVICE_TARGETS} | tee -a "$ROCM_PATH/bin/target.lst"
touch "${ROCM_PATH}/.info/version"
