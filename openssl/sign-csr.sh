#!/bin/bash

# Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Script to sign csr
#
# Usage:
#  sign-csr.sh server|client csr files 

DEFAULTCA="CA"

disclaimer() {
  echo "Se deben pasar como minimo dos argumentos:"
  echo "** El primero server para firmar un certificado para un servidor o client para un cliente."
  echo "** Resto de argumentos seran csr, todos del mismo tipo o cliente o servidor"
}

if [ $# -le 1 ]
then
  disclaimer
  exit 0
fi

case $1 in
  server)
    shift
    for i in $*
    do
      FILENAME=`basename $i | sed -e 's/\.csr//g'`
      CMD="openssl ca -extensions server -name "$DEFAULTCA" -out "$FILENAME".crt -infiles "$i
      echo "** Generando certificado para $i:"
      eval $CMD
    done
    ;;
  client)
    shift
    for i in $*
    do
      FILENAME=`basename $i | sed -e 's/\.csr//g'`
      CMD="openssl ca -name "$DEFAULTCA" -out "$FILENAME".crt -infiles "$i
      echo "** Generando certificado para $i:"
      eval $CMD
    done
    ;;
  *)
   disclaimer
   ;;
esac
