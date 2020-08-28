#!/bin/bash

# backup rudimentario 
# Jose Angel de Bustos Perez <jadebustos@gmail.com>

# requerimientos
#   - var tiene que estar montado en una particion
#   - locales en español

# observaciones
#   - se tiene que ejecutar como root
#   - se hace un full backup cada siete dias
#   - copia los enlaces tal cual, si al hacer el restore
#     el objetivo del enlace no existe por no estar en el
#     backup, se siente
#   - en caso de no existir el fichero fullbackupdatefile
#     se hace un full backup
#   - si /var esta a mas del 90 % no se realizan backups

# fichero de log
logfile=/var/log/mybackups.log

# directorios de los que hacer backup
dirs="/etc/ /var/log/backup/ "

# directorio en el que se almacenaran los backups
backupdir="/var/backups/"

# tiempo en segundos para el fullbackup
fullbackuptime=`echo "7 * 24 * 3600" | bc`

# dias que se mantendran los ficheros de backup
expiredtime=60

# fecha
date=`date`
todaydate=`date +%s`

# fichero que almacena la fecha del ultimo fullbackup
fullbackupdatedir=/var/spool/mybackups/
fullbackupdatefile=$fullbackupdatefile"myfullbackup.date"

if [ ! -d $fullbackupdatedir ]
then
  `mkdir -p $fullbackupdatedir > /dev/null 2>&1`
  if [ ! $? ]
  then
    `echo "\`date\` - No se pudo crear el directorio $fullbackupdatedir." >> $logfile`
    exit 0
  fi
fi

# fecha del ultimo fullbackup
lastfullbackup=0
if [ -e $fullbackupdatefile ]
then
  lastfullbackup=`cat $fullbackupdatefile`
fi

# en caso de no existir el directorio de backup lo crea
# y si hay algun problema al crearlo termina la ejecucion
if [ ! -d $backupdir ]
then
  `mkdir -p $backupdir > /dev/null 2>&1`
  if [ ! $? ]
  then
    `echo "\`date\` - No se pudo crear el directorio $backupdir." >> $logfile`
    exit 0
  fi
fi

# borrar los ficheros obsoletos
`find $backupdir -mtime $expiredtime | xargs -n 1 rm -f`

# si el porcentage de uso de /var/backups es superior al 90 % no se hace backup
varpercentage=`df -h | grep "/var/backups$" | awk -F' ' '{ print $5 }' | sed -e 's/%//g'`

# pmartin
#if [ $varpercentage -ge 90 ]
if [ $varpercentage -ge "90" ]
then
  `echo "\`date\` - No se realizo backup al estar /var/backups al $varpercentage %." >> $logfile`
  exit 0;
fi

# empezamos el backup

seconds=`echo $todaydate - $lastfullbackup | bc`

if [ $seconds -ge $fullbackuptime ]
then
  # full backup
  for dir in $dirs
  do
    # cambiamos "/" por "-"
    prefix=`echo $dir | sed -e 's/\//-/g'`
    backupfilename=`date +%G%m%d`$prefix"fullbackup.tgz"
    tar -czf $backupdir$backupfilename -V "Full backup de $prefix en $date" $dir
    # almacenamos la fecha del ultimo full backup realizado con exito
    if [ $? ]
    then
      `echo $todaydate > $fullbackupdatefile`
      `echo "\`date\` - Se realizo full backup de $dir en $backupdir$backupfilename." >> $logfile`
    else
      `echo "\`date\` - No se pudo hacer el full backup de $dir." >> $logfile`
      `rm -f $backupdir$backupfilename > /dev/null 2>&1`
    fi
 done
else
  # differencial backup
  for dir in $dirs
  do
    # cambiamos "/" por "-"
    prefix=`echo $dir | sed -e 's/\//-/g'`
    # fecha del ultimo full backup
    lastfullbackup=`cat $fullbackupdatefile`
    backupfilename=`date +%G%m%d`$prefix"differentialbackup.tgz"
    `tar -czf $backupdir$backupfilename -V "Differential backup de $prefix en $date" --newer-mtime $lastfullbackup $dir`
    if [ $? ]
    then
      `echo "\`date\` - Se realizo differential backup de $dir en $backupdir$backupfilename." >> $logfile`
    else
      `echo "\`date\` - No se pudo hacer el differential backup de $dir." >> $logfile`
      `rm -f $backupdir$backupfilename > /dev/null 2>&1`
    fi
  done
fi
