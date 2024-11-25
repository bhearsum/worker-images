#!/bin/bash

set -exv

function retry {
  set +e
  local n=0
  local max=10
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed" >&2
        sleep_time=$((2 ** n))
        echo "Sleeping $sleep_time seconds..." >&2
        sleep $sleep_time
        echo "Attempt $n/$max:" >&2
      else
        echo "Failed after $n attempts." >&2
        exit 1
      fi
    }
  done
  set -e
}

## When installing from https://cloud.google.com/compute/docs/gpus/install-drivers-gpu during packer it will fail since nvidia-smi 
## will try and access the GPU. During packer build, we don't build with a GPU, therefore the below script is extracted from 
## https://github.com/GoogleCloudPlatform/compute-gpu-installation/tree/main in an effort to install the drivers without a gpu

## Set the variables here (maybe move them into the config file)
#LATEST_DRIVER_VERSION="550.90.07"
#LATEST_DRIVER_URL="https://us.download.nvidia.com/tesla/${LATEST_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${LATEST_DRIVER_VERSION}.run"

# kernel_version=$(uname -r)
# image_package="linux-image-$kernel_version"
# header_package="linux-headers-$kernel_version"

# ## Let's lock kernal updates
# KERNEL_UPDATES=()
# KERNEL_UPDATES+=(linux-image-gcp linux-headers-gcp)
# KERNEL_UPDATES+=($image_package $header_package)
# retry apt-mark hold ${KERNEL_UPDATES[@]}

#retry curl -sSO $LATEST_DRIVER_URL
#chmod +x NVIDIA-Linux-x86_64-${LATEST_DRIVER_VERSION}.run

# Execute the .run file
#bash NVIDIA-Linux-x86_64-${LATEST_DRIVER_VERSION}.run -s

UBUNTU_RELEASE=$(lsb_release -rs) # 24.04
DISTRO=ubuntu${UBUNTU_RELEASE//\./} # ubuntu2404

## Install via network repo installation method https://docs.nvidia.com/cuda/archive/12.4.1/cuda-installation-guide-linux/index.html#network-repo-installation-for-ubuntu 
retry curl -sSO https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb

## Install the cuDNN libraries https://docs.nvidia.com/deeplearning/cudnn/latest/installation/linux.html#ubuntu-debian-network-installation 
apt-get update
CUDA=()
## meta-package name https://docs.nvidia.com/deeplearning/cudnn/latest/installation/linux.html#meta-packages
CUDA+=(cudnn9-cuda-12)
## base package name
CUDA+=(libcudnn9-cuda-12)
retry apt-get install -y ${CUDA[@]}