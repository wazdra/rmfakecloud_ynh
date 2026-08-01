rmfakecloud is available at <https://__DOMAIN__>.

## Signing in

An administrator account has been created for you:

- **Username:** `__ADMIN_LOGIN__`
- **Password:** the one you chose during the installation

This account belongs to rmfakecloud alone. It is **not** your YunoHost account:
rmfakecloud has no LDAP or SSO support, so it keeps its own user database under
`__DATA_DIR__/users`. Changing your YunoHost password does not change this one.

If your YunoHost username contains a `-`, the rmfakecloud account name has it
removed, because rmfakecloud rejects that character in account names. The
username shown above is the one that works.

## Managing users

To add a user, or reset a password:

```bash
yunohost app shell __ID__ <<< './rmfakecloud setuser -u USERNAME -p PASSWORD -s'
```

Add `-a` to make the account an administrator. Keep `-s` in every case: without
it the account is created with the modern sync protocol (sync15) disabled, which
recent reMarkable firmware needs.

To list existing accounts:

```bash
yunohost app shell __ID__ <<< './rmfakecloud listusers'
```

## Connecting a reMarkable device

The app must stay accessible to visitors: reMarkable devices authenticate
against paths such as `/token/json/2/device/new` without going through the
YunoHost portal, so restricting the app to YunoHost users would break syncing.
The device pairing code is generated from the web interface.

See the upstream guide: <https://ddvk.github.io/rmfakecloud/remarkable/setup/>
