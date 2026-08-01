#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# Run pnpm through Corepack's binary proxy.
#
# The usual idiom is `corepack enable && corepack prepare pnpm@X --activate`,
# avoided here on purpose: `corepack enable` writes a `pnpm` shim next to the
# corepack binary, in /opt/node_n/n/versions/node/$nodejs_version/bin, which is
# shared with every other app on the instance using the same Node version.
# `--activate` likewise sets a global default in the shared Corepack cache.
# The binary proxy writes nothing outside the pnpm store and pins the version
# per call, so our builds can neither affect nor be affected by other apps.
#
# Version 9 is required by ui/pnpm-lock.yaml (lockfileVersion 9.0), and has to
# be spelled out because upstream's package.json has no "packageManager" field.
#
# NB: Corepack ships with Node only up to 22.x. If resources.nodejs is bumped
# past 24, corepack will have to be installed separately.
rmfakecloud_pnpm() {
	ynh_hide_warnings corepack pnpm@9 "$@"
}

# Build the web UI, then the Go binary.
#
# Order matters: internal/ui/ui.go imports the `ui` package, whose assets.go
# does `//go:embed dist/*`, so `go build` fails outright unless the UI has been
# built into $install_dir/ui/dist first.
rmfakecloud_build() {
	pushd "$install_dir/ui" >/dev/null
		rmfakecloud_pnpm install --frozen-lockfile
		rmfakecloud_pnpm run build
	popd >/dev/null

	# node_modules is only needed to build the UI and weighs a few hundred MB.
	# Dropped before the Go build so both caches never sit on disk at once.
	ynh_safe_rm "$install_dir/ui/node_modules"

	# App scripts run with no $HOME, and the Go helper only sets $PATH and
	# $GOENV_ROOT. Go derives its cache paths from $HOME and, unlike Node, has
	# no getpwuid fallback, so it aborts with "module cache not found: neither
	# GOMODCACHE nor GOPATH is set". ynh_smart_mktemp picks somewhere with room
	# for the caches (measured: 650M modules + 249M build) and dies cleanly if
	# the disk is too full, rather than failing halfway through the build.
	local go_scratch
	go_scratch=$(ynh_smart_mktemp --min_size=1024)
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

# Render conf/rmfakecloud.env, loaded by the systemd unit as EnvironmentFile.
# Shared by install, upgrade and change_url, which all need the exact same
# template, permissions and ownership.
rmfakecloud_config_add() {
	ynh_config_add --template="rmfakecloud.env" --destination="$install_dir/rmfakecloud.env"

	# 600 rather than 400: the file holds the JWT signing key
	chmod 600 "$install_dir/rmfakecloud.env"
	chown "$app:$app" "$install_dir/rmfakecloud.env"
}
