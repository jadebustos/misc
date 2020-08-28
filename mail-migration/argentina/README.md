```
# perl mb2md-3.20.pl -s /home/jadebustos/migracion-correo/argentina/pruebas/mailbox -d /home/jadebustos/migracion-correo/argentina/pruebas/convert
```

In mailbox are placed the converted mbox files (converted from the solaris original mail files).

In convert a directory **.usuario** will be created.

To migrate them:

```
# perl imap2imap-ar.pl convert
```
