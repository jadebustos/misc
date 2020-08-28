#!/bin/bash

perl mb2md-3.20.pl -s /var/spool/mailbox/migracion-argentina/migracion/mailbox/ -d /var/spool/mailbox/migracion-argentina/migracion/convert/

rm -Rf convert/cur convert/new convert/tmp
