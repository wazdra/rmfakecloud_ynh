rmfakecloud is available at <https://__DOMAIN__>.

## Signing in

- **Username:** `__ADMIN_LOGIN__`
- **Password:** the one you chose during the installation

This account belongs to rmfakecloud alone, not to YunoHost: the app has no LDAP
or SSO support and keeps its own user database under `__DATA_DIR__/users`.
Changing your YunoHost password does not change this one.

If your YunoHost username contains a `-`, it has been removed above, because
rmfakecloud rejects that character in account names.

## Managing users

```bash
yunohost app shell __ID__ <<< './rmfakecloud setuser -u USERNAME -p PASSWORD -s'
```

Add `-a` for an administrator. Keep `-s` in every case, otherwise the account is
created with the modern sync protocol (sync15) disabled, which recent reMarkable
firmware needs. Use `./rmfakecloud listusers` to see existing accounts.

## Connecting a reMarkable device

<https://ddvk.github.io/rmfakecloud/remarkable/setup/>
