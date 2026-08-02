#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# General wrapper to run a build command as $app. 
rmfakecloud_exec_build() {
	ynh_hide_warnings ynh_exec_as_app env \
		HOME="$build_cache" \
		GOPATH="$build_cache/go" \
		GOCACHE="$build_cache/go-build" \
		"$@"
}

# Build the web UI, then the Go binary.
rmfakecloud_build() {
	local build_cache
	build_cache=$(ynh_smart_mktemp --min_size=1536)
	chown "$app:$app" "$build_cache"

    # WebUI build
	pushd "$install_dir/ui" >/dev/null
		rmfakecloud_exec_build corepack pnpm@9 install --frozen-lockfile
		rmfakecloud_exec_build corepack pnpm@9 run build
	popd >/dev/null

	# ~326M, and no longer needed once ui/dist exists
	ynh_safe_rm "$install_dir/ui/node_modules"

    # Go backend build
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

# EnvironmentFile for the systemd unit
rmfakecloud_config_add() {
	ynh_config_add --template="rmfakecloud.env" --destination="$install_dir/rmfakecloud.env"

	# holds the JWT signing key
	chmod 600 "$install_dir/rmfakecloud.env"
	chown "$app:$app" "$install_dir/rmfakecloud.env"
}
