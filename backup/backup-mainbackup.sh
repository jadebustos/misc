#!/bin/bash

# very simple backup script for laptop
# (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> 
#     Distributed under GNU GPL v2 License                    
#     See COPYING.txt for more details

SOURCE_DIR=(
           '/home/jadebustos/')

TARGET_DIR=(
           '/media/mainbackup/Red Hat/jadebustos/')

for index in ${!SOURCE_DIR[*]}
do
  SOURCE=${SOURCE_DIR[$index]}
  TARGET=${TARGET_DIR[$index]}
  # check if target dir exists
  if [ ! -d "$TARGET" ]
  then
    mkdir -p $TARGET
  fi
  CMD="rsync -aP --delete '$SOURCE' '$TARGET'"
  echo "Haciendo backup de $SOURCE a $TARGET"  
  eval $CMD
done




