## User management

The password can be changed from rmfakecloud's web interface.
Changing the password of your YunoHost account does not change this one (and vice versa).

Additional accounts can be created from the web interface, or from the command line:

```bash
yunohost app shell __ID__ <<< './rmfakecloud setuser -u USERNAME -p PASSWORD -s'
```

Add `-a` for an administrator account. Remove `-s` to use the old sync protocol (specific cases).
`./rmfakecloud listusers` lists existing accounts.

## Connecting a tablet

See <https://ddvk.github.io/rmfakecloud/remarkable/setup/>
