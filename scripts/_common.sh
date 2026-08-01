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
	pushd "$install_dir/ui" >/dev/null
		rmfakecloud_pnpm install --frozen-lockfile
		rmfakecloud_pnpm run build
	popd >/dev/null

	# node_modules is only needed to build the UI and weighs a few hundred MB.
	# Dropped before the Go build so the two caches never coexist on disk.
	ynh_safe_rm "$install_dir/ui/node_modules"

	# YunoHost runs app scripts with no $HOME, and its Go helper only sets $PATH
	# and $GOENV_ROOT. Go resolves its cache paths from $HOME and, unlike Node,
	# has no getpwuid fallback, so it aborts with "module cache not found:
	# neither GOMODCACHE nor GOPATH is set".
	# ynh_smart_mktemp picks a location with enough room (measured: 650M of
	# module cache + 249M of build cache) and aborts cleanly if the disk is too
	# full, instead of failing halfway through the build.
	local go_scratch
	go_scratch="$(ynh_smart_mktemp --min_size=1024)"
	export GOPATH="$go_scratch/path"
	export GOCACHE="$go_scratch/cache"
	mkdir --parents "$GOPATH" "$GOCACHE"

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

# Render conf/rmfakecloud.env, which the systemd unit loads as EnvironmentFile.
#
# ynh_config_add is used rather than writing the file by hand: it backs the file
# up if the admin edited it, stores a checksum in the app settings so the next
# upgrade can detect that, and creates the file with safe ownership before
# writing (avoiding a pre-created-file attack). It also aborts if any __VAR__ in
# the template has no matching shell variable, which is why no manual guard on
# $port_mqtt is needed any more.
rmfakecloud_write_environment() {
	ynh_config_add --template="rmfakecloud.env" --destination="$install_dir/rmfakecloud.env"

	chmod 600 "$install_dir/rmfakecloud.env"
	chown "$app:$app" "$install_dir/rmfakecloud.env"
}
