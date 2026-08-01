## Gestion des utilisateurs

Le mot de passe peut être modifié dans l'interface Web de rmfakecloud.
Modifier le mot de passe de son compte Yunohost ne change pas ce mot de passe (et inversement).

Des comptes supplémentaires peuvent être créés via l'interface Web, ou par la ligne de commande:

```bash
yunohost app shell __ID__ <<< './rmfakecloud setuser -u USERNAME -p PASSWORD -s'
```

Ajouter `-a` pour un compte administrateur. Retirer `-s` pour utiliser l'ancien protocole de synchronisation (cas spécifiques).
`./rmfakecloud listusers` liste les comptes existants.

## Connexion d'une tablette

Se référer à <https://ddvk.github.io/rmfakecloud/remarkable/setup/>
