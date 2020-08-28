
```
$ perl mb2md-3.20.pl -s /home/jadebustos/migracion-correo/uruguay/pruebas/mailbox -d /home/jadebustos/migracion-correo/uruguay/pruebas/convert
```

In mailbox are placed the converted mbox files (converted from the solaris original mail files).

In convert a directory **.usuario** will be created.

To migrate them:

```
$ perl imap2imap-ur.pl convert
```
