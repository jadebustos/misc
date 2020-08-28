#!/bin/bash

#
# (c) 2009, Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
# Distributed under GNU GPL v2 License
# See COPYING.txt for more details

# Script para la restauracion de maquinas virtuales a partir del vcb
# Este script fue desarrollado para ESX version 3.0 y 3.5

if [ $# -ne 1 ]
then
  echo "$0 Fichero catalog"
  exit 1;
fi 

# Punto de montaje donde se montara la imagen a restaurar
MOUNT_POINT=/mnt/vcbrestore
# Unidad de red donde se encuentra la imagen a restaurar
SHARE=//ucaivcb.ucai.onif/vcbrestore
# Usuario local a la maquina Windows para montar la unidad
USER=Administrator

# Montamos la unidad de red
echo "****************************************************************************************"
echo "* Se va a montar en $MOUNT_POINT la unidad $SHARE           *"
echo "* Sera necesario introducir el password del usuario $USER local de la maquina  *"
echo "* EL PASSWORD DEL USUARIO LOCAL NO EL DEL DOMINIO UCAI.ONIF                            *"
echo "****************************************************************************************"
echo " "

`smbmount $SHARE $MOUNT_POINT -o username=$USER`

# Comprobamos el resultado
if [ $? -ne 0 ]
then
  echo "Ocurrio un error, comprueba que el recurso $SHARE esta correctamente compartido y"
  echo "que el password sea el del usuario local de la maquina y no el del dominio."
  exit 1
fi

# Comprobamos el DATASTORE en el que se restaurara la maquina
CATALOG=$1

DATASTORE=`grep config.vmx $CATALOG | awk -F'[' '{print $2}' | sed -e 's/].*//g'`
DATASTOREORI=$DATASTORE

echo " "
echo " "
echo " "

RES=12
while [ $RES -ne 0 -a $RES -ne 1 ]
do
  echo "   0 - Desea restaurar la maquina en el DataStore $DATASTORE"
  echo "   1 - Desea cambiar el DataStore de destino"
  echo " "
  echo -n "   Opcion: "
  read RES
  while [ ! -d "/vmfs/volumes/$DATASTORE" ]
  do
    echo "      El DataStore $DATASTORE no ha sido encontrado."
    echo -n "      Introduzca el nombre de un DataStore existente: "
    read DATASTORE
  done
done

if [ $RES -eq 1 ]
then
  echo -n "      Introduzca el nombre del nuevo DataStore: "
  read DATASTORE
  while [ ! -d "/vmfs/volumes/$DATASTORE" ]
  do
    echo "         El DataStore $DATASTORE no ha sido encontrado."
    echo -n "         Introduzca el nombre de un DataStore existente: "
    read DATASTORE
  done
fi

# Directorio donde esta la maquina a restaurar
BACKUP_DIR=`echo $CATALOG | sed -e 's/\/catalog//g'`

# Cambiamos el DataStore en el fichero de catalogo
TEMPORAL=/tmp/prueba
`cat $CATALOG | sed -e "s/$DATASTOREORI/$DATASTORE/g" > $TEMPORAL`
mv $TEMPORAL $CATALOG

echo " "

echo "Se va a proceder a restaurar la maquina virtual. Sera necesario suministrar"
echo "el password del ESX."

echo " "

vcbRestore -h localhost -u root -s $BACKUP_DIR -b overwrite

# Desmontamos
`umount $MOUNT_POINT`
