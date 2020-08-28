#!/bin/bash

# Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Script to get emails from generated certs
#

CERTSDIR=/etc/pki/CA/newcerts
LISTEMAIL=''
for cert in `ls $CERTSDIR`
do
  CERTFILE=$CERTSDIR"/"$cert
  EMAIL=`cat $CERTFILE | grep Subject | awk -F',' '{print $5}' | awk -F'=' '{print $3}'`
  LISTEMAIL=$LISTEMAIL' \n '$EMAIL
done

echo -e $LISTEMAIL | sort | uniq
