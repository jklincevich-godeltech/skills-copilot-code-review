#!/bin/bash

set -euo pipefail

# Install MongoDB
KEYRING_PATH="/usr/share/keyrings/mongodb-server-7.0.gpg"
KEY_URL="https://pgp.mongodb.com/server-7.0.asc"
MONGO_VERSION="${MONGO_VERSION:-7.0.16}"
MONGOSH_VERSION="${MONGOSH_VERSION:-2.3.8}"

install_mongodb_from_tarball() {
	local architecture
	local mongo_arch
	local tarball_name
	local download_url
	local temp_dir

	architecture="$(dpkg --print-architecture)"
	case "$architecture" in
	amd64)
		mongo_arch="x86_64"
		;;
	arm64)
		mongo_arch="aarch64"
		;;
	*)
		echo "Unsupported architecture for MongoDB tarball fallback: $architecture" >&2
		exit 1
		;;
	esac

	tarball_name="mongodb-linux-${mongo_arch}-ubuntu2204-${MONGO_VERSION}.tgz"
	download_url="https://fastdl.mongodb.org/linux/${tarball_name}"
	temp_dir="$(mktemp -d)"

	echo "APT install failed due to repository signature policy. Falling back to tarball install: ${download_url}"
	curl -fsSL "$download_url" -o "$temp_dir/$tarball_name"
	sudo tar -xzf "$temp_dir/$tarball_name" -C /opt
	sudo ln -sf "/opt/mongodb-linux-${mongo_arch}-ubuntu2204-${MONGO_VERSION}/bin/mongod" /usr/local/bin/mongod
	sudo ln -sf "/opt/mongodb-linux-${mongo_arch}-ubuntu2204-${MONGO_VERSION}/bin/mongos" /usr/local/bin/mongos
	rm -rf "$temp_dir"
}

install_mongosh_from_tarball() {
	if command -v mongosh >/dev/null 2>&1; then
		return
	fi

	local architecture
	local mongosh_arch
	local tarball_name
	local download_url
	local temp_dir

	architecture="$(dpkg --print-architecture)"
	case "$architecture" in
	amd64)
		mongosh_arch="x64"
		;;
	arm64)
		mongosh_arch="arm64"
		;;
	*)
		echo "Unsupported architecture for mongosh tarball fallback: $architecture" >&2
		exit 1
		;;
	esac

	tarball_name="mongosh-${MONGOSH_VERSION}-linux-${mongosh_arch}.tgz"
	download_url="https://downloads.mongodb.com/compass/${tarball_name}"
	temp_dir="$(mktemp -d)"

	echo "Installing mongosh from tarball fallback: ${download_url}"
	curl -fsSL "$download_url" -o "$temp_dir/$tarball_name"
	sudo tar -xzf "$temp_dir/$tarball_name" -C /opt
	sudo ln -sf "/opt/mongosh-${MONGOSH_VERSION}-linux-${mongosh_arch}/bin/mongosh" /usr/local/bin/mongosh
	rm -rf "$temp_dir"
}

if ! curl -fsSL "$KEY_URL" | sudo gpg --batch --yes --dearmor -o "$KEYRING_PATH"; then
	curl -fsSL "$KEY_URL" | sudo gpg --batch --yes --allow-weak-key-signatures --dearmor -o "$KEYRING_PATH"
fi

echo "deb [ arch=amd64,arm64 signed-by=$KEYRING_PATH ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
if sudo apt-get update && sudo apt-get install -y mongodb-org mongodb-mongosh; then
	echo "MongoDB installed from apt repository"
else
	install_mongodb_from_tarball
	install_mongosh_from_tarball
fi

if ! id -u mongodb >/dev/null 2>&1; then
	sudo useradd --system --home /var/lib/mongodb --shell /usr/sbin/nologin mongodb
fi

# Create necessary directories and set permissions
sudo mkdir -p /data/db
sudo chown -R mongodb:mongodb /data/db
