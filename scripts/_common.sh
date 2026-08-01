#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# Run one build command as $app, with every cache pointed at $build_cache.
#
# $build_cache is a local of rmfakecloud_build; bash's dynamic scoping makes it
# visible here. If this is ever called from anywhere else it will abort on the
# unset variable, since the helpers enable `set -o nounset`.
#
# sudo resets the environment and ynh_exec_as_app only forwards PATH, so
# anything the build needs must be listed explicitly below.
#
# HOME is the important one. resources.system_user gives the app user
# /var/www/__APP__ as its home, which is exactly $install_dir -- a directory
# that gets backed up by scripts/backup and wiped by `ynh_setup_source
# --full_replace`. Left alone, corepack's cache and pnpm's store would be
# written there and end up inside every backup archive.
rmfakecloud_exec_build() {
	ynh_hide_warnings ynh_exec_as_app env \
		HOME="$build_cache" \
		GOPATH="$build_cache/go" \
		GOCACHE="$build_cache/go-build" \
		"$@"
}

# Build the web UI, then the Go binary.
#
# Order matters: internal/ui/ui.go imports the `ui` package, whose assets.go
# does `//go:embed dist/*`, so `go build` fails outright unless the UI has been
# built into $install_dir/ui/dist first.
rmfakecloud_build() {
	# Scratch space for all build caches, measured: 322M pnpm store, 646M Go
	# module cache, 250M Go build cache. ynh_smart_mktemp picks a filesystem
	# with room and dies cleanly if there is none, rather than failing halfway
	# through the build.
	# NB: app scripts run without $HOME, and the Go helper sets only $PATH and
	# $GOENV_ROOT, so Go cannot derive its cache paths on its own -- it aborts
	# with "module cache not found: neither GOMODCACHE nor GOPATH is set".
	local build_cache
	build_cache=$(ynh_smart_mktemp --min_size=1536)
	chown "$app:$app" "$build_cache"

	# pnpm runs dependency postinstall scripts, so this deliberately does not
	# run as root.
	#
	# Corepack's binary proxy is used rather than the more common
	# `corepack enable && corepack prepare pnpm@X --activate`: `corepack enable`
	# writes a `pnpm` shim next to the corepack binary, under
	# /opt/node_n/n/versions/node/$nodejs_version/bin, which is shared with every
	# other app on the instance using the same Node version, and `--activate`
	# sets a global default in the shared Corepack cache. The proxy touches
	# neither, and pins the version per call.
	#
	# Version 9 is required by ui/pnpm-lock.yaml (lockfileVersion 9.0), spelled
	# out because upstream's package.json has no "packageManager" field.
	# NB: Corepack ships with Node only up to 22.x. If resources.nodejs is
	# bumped past 24, corepack will have to be installed separately.
	pushd "$install_dir/ui" >/dev/null
		rmfakecloud_exec_build corepack pnpm@9 install --frozen-lockfile
		rmfakecloud_exec_build corepack pnpm@9 run build
	popd >/dev/null

	# node_modules is only needed to build the UI and weighs ~326M. Dropped
	# before the Go build so the two never sit on disk at once.
	ynh_safe_rm "$install_dir/ui/node_modules"

	pushd "$install_dir" >/dev/null
		rmfakecloud_exec_build go build \
			-ldflags "-s -w -X main.version=$YNH_APP_MANIFEST_VERSION" \
			-o "$install_dir/rmfakecloud" \
			./cmd/rmfakecloud
	popd >/dev/null

	ynh_safe_rm "$build_cache"

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
