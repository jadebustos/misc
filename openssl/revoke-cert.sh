#!/bin/bash

# Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Script to sign csr
#
# Usage:
#  sign-csr.sh server|client csr files 

DEFAULTCA="CA"
CACRLFILE="/etc/pki/CA/comcrl.pem"

disclaimer() {
  echo "Se debe pasar como minimo un certificado a revocar." 
}

if [ $# -le 0 ]
then
  disclaimer
  exit 0
fi

for i in $*
do
   SERIAL=`cat $i | grep "Serial Number" | awk -F'0x' '{print $2}' | sed -e 's/)//g' | tr '[:lower:]' '[:upper:]'`
   TEST=`echo $SERIAL | wc -m`
   if [ $TEST -lt 3 ]
   then
     SERIAL="0"$SERIAL
   fi
   echo "Verificando $i"
   CMD="openssl crl -in "$CACRLFILE"  -noout -text | grep \"Serial Number: "$SERIAL"\" > /dev/null 2>&1"
   eval $CMD
   RC=$?
   if [ $RC = 0 ]
   then
     echo "El certificado $i ya fue revocado con anterioridad. No se realiza ninguna accion."
   else
     CMD="openssl ca -name $DEFAULTCA -revoke $i"
     echo "Revocando $i"
     eval $CMD
     # Haciendo backup del actual fichero de crl
     TIMESTAMP=`date +%Y%m%d%H%M%S`
     CMD="cp $CACRLFILE /etc/pki/CA/crl/crl-$TIMESTAMP.pem"
     echo "Haciendo backup del actual fichero de crl a /etc/pki/CA/crl/crl-$TIMESTAMP.pem"
     eval $CMD
     CMD="openssl ca -name $DEFAULTCA -gencrl -out $CACRLFILE"
     echo "Generando nuevo fichero de revocacion"
     eval $CMD
     echo "No se te olvide actualizar el fichero de revocaciones del servidor OpenVPN"
     echo "con $CACRLFILE y reiniciar el servicio OpenVPN."
   fi
done
