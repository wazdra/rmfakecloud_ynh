#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# Run a build command as $app. sudo drops the environment, so pass it explicitly.
# HOME must not be the app user's real home: that is $install_dir, which is
# backed up and wiped on upgrade.
rmfakecloud_exec_build() {
	ynh_hide_warnings ynh_exec_as_app env \
		HOME="$build_cache" \
		GOPATH="$build_cache/go" \
		GOCACHE="$build_cache/go-build" \
		"$@"
}

# Build the web UI, then the Go binary. That order is mandatory: the binary
# embeds ui/dist via go:embed.
rmfakecloud_build() {
	# Go cannot find its own cache paths without $HOME, which app scripts lack
	local build_cache
	build_cache=$(ynh_smart_mktemp --min_size=1536)
	chown "$app:$app" "$build_cache"

	# pnpm 9 per ui/pnpm-lock.yaml. Corepack's binary proxy avoids installing a
	# shim into the Node dir shared with other apps.
	pushd "$install_dir/ui" >/dev/null
		rmfakecloud_exec_build corepack pnpm@9 install --frozen-lockfile
		rmfakecloud_exec_build corepack pnpm@9 run build
	popd >/dev/null

	# ~326M, and no longer needed once ui/dist exists
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

# Brute-force jail on the login form, reading NGINX's access log like YunoHost's
# own jails do. A helper because change_url must re-apply it (per-domain path).
# NB: do not wrap ynh_config_add_nginx the same way -- package_check greps
# scripts/install for it to decide the app is a webapp.
rmfakecloud_fail2ban_add() {
	ynh_config_add_fail2ban \
		--logpath="/var/log/nginx/$domain-access.log" \
		--failregex='^<HOST> -.*"POST /ui/api/login HTTP/\d\.\d" 401'
}

# EnvironmentFile for the systemd unit
rmfakecloud_config_add() {
	ynh_config_add --template="rmfakecloud.env" --destination="$install_dir/rmfakecloud.env"

	# holds the JWT signing key
	chmod 600 "$install_dir/rmfakecloud.env"
	chown "$app:$app" "$install_dir/rmfakecloud.env"
}
