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

## This is from https://github.com/GoogleCloudPlatform/compute-gpu-installation/releases
if test -f /opt/google/cuda-installer
then
  exit
fi

mkdir -p /opt/google/cuda-installer/
cd /opt/google/cuda-installer/ || exit

retry curl -fSsL -O https://github.com/GoogleCloudPlatform/compute-gpu-installation/releases/download/cuda-installer-v1.1.0/cuda_installer.pyz
python3 cuda_installer.pyz install_cuda

python3 cuda_installer.pyz verify_cuda