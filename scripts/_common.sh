#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# Run pnpm through Corepack's binary proxy.
#
# The usual idiom in YunoHost packages is `corepack enable && corepack prepare
# pnpm@X --activate`. That is avoided here on purpose: `corepack enable` writes
# a `pnpm` shim into the directory holding the corepack binary, which is
# /opt/node_n/n/versions/node/$nodejs_version/bin -- shared with *every other
# app on the instance* using the same Node version. `--activate` likewise sets
# a global default package-manager version in the shared Corepack cache.
# The binary proxy writes nothing outside the pnpm store and pins the version
# per call, so no other app can be affected by (or affect) our builds.
#
# Version 9 is required by ui/pnpm-lock.yaml (lockfileVersion 9.0). It has to
# be spelled out because upstream's package.json has no "packageManager" field.
#
# NB: Corepack ships with Node up to 22.x. If resources.nodejs is ever bumped
# past 24, corepack has to be installed separately.
#
# COREPACK_ENABLE_DOWNLOAD_PROMPT is already exported by YunoHost's nodejs
# helper, so Corepack will not stop to ask for confirmation.
rmfakecloud_pnpm() {
	ynh_hide_warnings corepack pnpm@9 "$@"
}

# Build the web UI and the Go binary.
# The UI *must* be built first: internal/ui/ui.go imports the `ui` package,
# whose assets.go does `//go:embed dist/*`, so `go build` fails outright if
# $install_dir/ui/dist does not exist yet.
rmfakecloud_build() {
	# Scratch space for the Go caches, see below. Kept inside $install_dir so it
	# lands on the same filesystem the `disk` manifest key accounts for.
	local go_scratch="$install_dir/.gobuild"

	pushd "$install_dir/ui" >/dev/null
		rmfakecloud_pnpm install --frozen-lockfile
		rmfakecloud_pnpm run build
	popd >/dev/null

	# Drop node_modules (a few hundred MB) before the Go build rather than after,
	# so the two caches never occupy the disk at the same time.
	ynh_safe_rm "$install_dir/ui/node_modules"

	# YunoHost runs app scripts with no $HOME, and its Go helper only sets $PATH
	# and $GOENV_ROOT. Go resolves its cache paths from $HOME and, unlike Node,
	# has no getpwuid fallback, so it aborts with "module cache not found:
	# neither GOMODCACHE nor GOPATH is set". Point the caches at our own scratch
	# dir: this is also better isolation than a shared root-owned ~/go that
	# every other app's build would share.
	export GOPATH="$go_scratch/path"
	export GOCACHE="$go_scratch/cache"
	mkdir -p "$GOPATH" "$GOCACHE"

	pushd "$install_dir" >/dev/null
		ynh_hide_warnings go build \
			-ldflags "-s -w -X main.version=$YNH_APP_MANIFEST_VERSION" \
			-o "$install_dir/rmfakecloud" \
			./cmd/rmfakecloud
	popd >/dev/null

	ynh_safe_rm "$go_scratch"

	chown -R "$app:$app" "$install_dir"
	chmod 750 "$install_dir/rmfakecloud"
}

rmfakecloud_write_environment() {
	local jwt_secret_key="${1:-}"
	local storage_url="${2:-}"
	local loglevel="${3:-info}"

	cat >"$install_dir/rmfakecloud.env" <<EOF
JWT_SECRET_KEY=$jwt_secret_key
STORAGE_URL=$storage_url
PORT=$port
MQTT_PORT=${port_mqtt:?port_mqtt setting is missing}
DATADIR=$data_dir
LOGLEVEL=$loglevel
RM_HTTPS_COOKIE=true
RM_TRUST_PROXY=true
EOF

	chown "$app:$app" "$install_dir/rmfakecloud.env"
	chmod 600 "$install_dir/rmfakecloud.env"
}
