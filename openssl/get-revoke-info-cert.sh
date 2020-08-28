#!/bin/bash

# Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Script to get revocation info about certificates using email addresses
#

CERTSDIR=/etc/pki/CA/newcerts
CAFILE=/etc/pki/CA/ca.crt
CRLFILE=/etc/pki/CA/crl.pem

if [ ! $# -gt 0 ]
then
   echo "Se debe pasar al menos una direccion de correo para localizar sus certificados."
   exit 0
fi

CERTS=`ls $CERTSDIR`

for email in `echo $*`
do
  for cert in `echo $CERTS`
  do
    CERTPATH=$CERTSDIR"/"$cert
    CMD="cat $CERTPATH | grep Subject | grep emailAddress | grep $email > /dev/null 2>&1"
    eval $CMD
    RC=$?
    # si el certificado esta asociado al email
    if [ $RC -eq 0 ]
    then
      CMD="openssl verify -CAfile $CAFILE -CRLfile $CRLFILE -crl_check $CERTPATH | grep revoked > /dev/null 2>&1"
      eval $CMD
      RC=$?
      if [ $RC -eq 0 ]
      then
         echo "$CERTPATH asociado a $email REVOCADO"
      else
         VALIDEZ=`cat $CERTPATH | grep After | sed -e 's/.*Not After ://g'`
         echo "$CERTPATH asociado a $email en VIGOR hasta$VALIDEZ"
      fi
    fi
  done
done
