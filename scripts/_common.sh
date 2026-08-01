#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

rmfakecloud_write_environment() {
	local jwt_secret_key="${1:-}"
	local storage_url="${2:-}"
	local loglevel="${3:-info}"

	cat >"$install_dir/rmfakecloud.env" <<EOF
JWT_SECRET_KEY=$jwt_secret_key
STORAGE_URL=$storage_url
PORT=$port
DATADIR=$data_dir
LOGLEVEL=$loglevel
RM_HTTPS_COOKIE=true
RM_TRUST_PROXY=true
EOF

	chown "$app:$app" "$install_dir/rmfakecloud.env"
	chmod 600 "$install_dir/rmfakecloud.env"
}
