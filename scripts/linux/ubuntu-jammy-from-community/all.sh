#!/bin/bash

set -exv

# init helpers
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

# taken from https://github.com/taskcluster/community-tc-config/blob/main/imagesets/generic-worker-ubuntu-22-04/bootstrap.sh

# ensure we're on a platform that's supported
case "$(uname -m)" in
  x86_64)
    ARCH=amd64
    ;;
  aarch64)
    ARCH=arm64
    ;;
  *)
    echo "Unsupported architecture '$(uname -m)' - currently bootstrap.sh only supports architectures x86_64 and aarch64" >&2
    exit 64
    ;;
esac

#
# taken from https://github.com/taskcluster/community-tc-config/blob/main/imagesets/generic-worker-ubuntu-22-04/bootstrap.sh
#

retry apt-get update
DEBIAN_FRONTEND=noninteractive retry apt-get upgrade -yq
retry apt-get -y remove docker docker.io containerd runc
# build-essential is needed for running `go test -race` with the -vet=off flag as of go1.19
retry apt-get install -y apt-transport-https ca-certificates curl software-properties-common gzip python3-venv build-essential

# install docker
retry curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
retry apt-get update
retry apt-get install -y docker-ce docker-ce-cli containerd.io
retry docker run hello-world

# removed kvm vmware backdoor

cd /usr/local/bin
retry curl -fsSL "https://github.com/taskcluster/taskcluster/releases/download/v${TASKCLUSTER_VERSION}/generic-worker-multiuser-linux-${ARCH}" > generic-worker
retry curl -fsSL "https://github.com/taskcluster/taskcluster/releases/download/v${TASKCLUSTER_VERSION}/start-worker-linux-${ARCH}" > start-worker
retry curl -fsSL "https://github.com/taskcluster/taskcluster/releases/download/v${TASKCLUSTER_VERSION}/livelog-linux-${ARCH}" > livelog
retry curl -fsSL "https://github.com/taskcluster/taskcluster/releases/download/v${TASKCLUSTER_VERSION}/taskcluster-proxy-linux-${ARCH}" > taskcluster-proxy
chmod a+x generic-worker start-worker taskcluster-proxy livelog

"https://github.com/taskcluster/taskcluster/releases/download/v69.0.1/generic-worker-multiuser-linux-amd64"

mkdir -p /etc/generic-worker
mkdir -p /var/local/generic-worker
mkdir -p /etc/taskcluster/secrets/
/usr/local/bin/generic-worker --version
/usr/local/bin/generic-worker new-ed25519-keypair --file /etc/generic-worker/ed25519_key

# ensure host 'taskcluster' resolves to localhost
echo 127.0.1.1 taskcluster >> /etc/hosts

# configure generic-worker to run on boot
# AJE: changed RequiredBy to multi-user
cat > /lib/systemd/system/worker.service << EOF
[Unit]
Description=Start TC worker

[Service]
Type=simple
ExecStart=/usr/local/bin/start-worker /etc/start-worker.yml
# log to console to make output visible in cloud consoles, and syslog for ease of
# redirecting to external logging services
StandardOutput=syslog+console
StandardError=syslog+console
User=root

[Install]
RequiredBy=multi-user.target
EOF

cat > /etc/start-worker.yml << EOF
provider:
    providerType: ${CLOUD}
worker:
    implementation: generic-worker
    path: /usr/local/bin/generic-worker
    configPath: /etc/generic-worker/config
cacheOverRestarts: /etc/start-worker-cache.json
EOF

systemctl enable worker

# install podman for d2g functionality
# - removed desktop packages, now in '...-gui' script dir
retry apt-get install -y podman

# set podman registries conf
(
  echo '[registries.search]'
  echo 'registries=["docker.io"]'
) >> /etc/containers/registries.conf

# omitting /etc/cloud/cloud.cfg.d/01_network_renderer_policy.cfg tweaks

# add additional packages

MISC_PACKAGES=()
# essentials
MISC_PACKAGES+=(build-essential curl git gnupg-agent jq mercurial)
# python things
MISC_PACKAGES+=(python3-pip python3-certifi python3-psutil)
# zstd packages
MISC_PACKAGES+=(zstd python3-zstd)
# things helpful for apt
MISC_PACKAGES+=(apt-transport-https ca-certificates software-properties-common)
# docker-worker needs this for unpacking lz4 images, perhaps uneeded but shouldn't hurt
MISC_PACKAGES+=(liblz4-tool)
# random bits
MISC_PACKAGES+=(libhunspell-1.7-0 libhunspell-dev)

retry apt-get install -y ${MISC_PACKAGES[@]}

pip3 install zstandard

# to enable snap testing

# create group
groupadd snap_sudo

# add sudoers entry for the group
echo '%snap_sudo ALL=(ALL:ALL) NOPASSWD: /usr/bin/snap' | EDITOR='tee -a' visudo


# hg

#
# setup robustcheckout
#

RC_PLUGIN="/etc/hgext/robustcheckout.py"
RC_URL="https://hg.mozilla.org/hgcustom/version-control-tools/raw-file/tip/hgext/robustcheckout/__init__.py"

mkdir /etc/hgext
chmod 0755 /etc/hgext
chown -R root:root /etc/hgext

curl -o $RC_PLUGIN $RC_URL
chmod 0644 $RC_PLUGIN

cat << EOF > /etc/mercurial/hgrc
[extensions]
robustcheckout = $RC_PLUGIN
EOF

# test
hg --version
hg showconfig | grep robustcheckout
hg robustcheckout --help

rm -rf /usr/src/*

# Do one final package cleanup, just in case.
apt-get autoremove -y --purge
