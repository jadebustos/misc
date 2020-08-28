#!/bin/bash

# (c) 2012 Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
#     Distributed under GNU GPL v2 License                    
#     See COPYING.txt for more details                        

SCRIPT_VERSION="0.99999 BETA"
NON_FATAL_ERROR_LOG_CODE=2
ERROR_LOG_CODE=1
OK_LOG_CODE=0
CNF_FILE=$1
LOCAL_HOSTNAME=`hostname`
DELAY=2

RSRC_FILE="/tmp/rsrc.tmp"
LSSAM_OUTPUT_FILE="/tmp/lssam-output.tmp"
SRV_IFACE="eth1"

# TSAM RESOURCE NAMES

TSAM_RSRC_VIP_NAME="vip_rs"
TSAM_RSRC_SCRIPT_NAME="app-control_rs"
TSAM_FS_RSRC_NAME="filesystems_rg"

# TSAM RELATIONSHIP NAMES

TSAM_NIC_RLTSHIP_NAME="srvnic_eq"
TSAM_LINK_RLTSHIP_NAME="niclink_rel"
TSAM_SCRIPT_IP_RLTSHIP_NAME="ipup_rel"
TSAM_SCRIPT_FS_RLTSHIP_NAME="fsmnt_rel"

#
# FUNCTION TO LOG
#
# $1 TEXT TO LOG
# $2 == 0 OK
# $2 == 1 ERROR
# $2 == 2 WARNING

log_info () {
        TIMESTAMP=`date +"%h %Y %d-%H:%M:%S"`
        echo $TIMESTAMP" - "$1 >> $LOG_FILE
        if [ $2 -eq 1 ]
        then
                echo $TIMESTAMP" - Finishing installation with errors." >> $LOG_FILE
        fi
        if [ $2 -eq 2 ]
        then
                echo $TIMESTAMP" - A non fatal error took place." >> $LOG_FILE
        fi
}

#
# CHECK IF A FILE EXISTS
#
# $1 FILE TO CHECK

check_file_exists () {
	
	if [ -f $1 ] 
	then
		return 0
	fi

	return 1
}

#
# ACTIVATE VG
#
#
# $1 VG TO ACTIVATE

activating_vg () {

	CMD_VG_ACTIVATION="vgchange -a y $1"
	log_info "Executing $CMD_VG_ACTIVATION" $OK_LOG_CODE
        eval $CMD_VG_ACTIVATION
        rc=$?
        if [ $rc -ne 0 ]
        then
        	log_info "Error activating $vg volume group. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

        log_info "Volume group $vg successfully activated." $OK_LOG_CODE
}

#
# FSTAB MODIFICATIONS - SETS TO noauto ALL THE LVs IN ARGS VG
#
#
#  ARGs VGs TO PARSE

fstab_mod () {
        VGs=`echo $* | tr ',' ' '`
	FSTAB_FILE=/etc/fstab
	TMP_FILE=/tmp/fstab
	FSTAB_TIMESTAMP=`date +%Y%m%d%H%M%S`
	FSTAB_FILE_BCK=$FSTAB_FILE"-"$FSTAB_TIMESTAMP

	# WE MAKE A BACKUP OF /etc/fstab USING A TIMESTAMP TO BE ABLE TO REVERSE THE CHANGE
	CMD_AWK="awk 'BEGIN{print \"# $FSTAB_TIMESTAMP\"}1' $FSTAB_FILE"
        log_info "Modifying $FSTAB_FILE using $CMD_AWK to include a timestamp." $OK_LOG_CODE
	eval $CMD_AWK > $TMP_FILE 2>&1
	cp $FSTAB_FILE $FSTAB_FILE_BCK
	log_info "Making a backup of $FSTAB_FILE to $FSTAB_FILE_BCK." $OK_LOG_CODE
	mv -f $TMP_FILE $FSTAB_FILE
	rc=$?
        if [ $rc -ne 0 ]
        then
 	       log_info "$FSTAB_FILE could not be modified. Aborting." $ERROR_LOG_CODE
               exit 1
        fi


        for vg in $VGs
        do
                # GET RID OF ,auto|noauto, OPTIONS
                CMD_AWK="awk '\$1~\"$vg\"{gsub(\",.*auto,\",\",\",\$4)}1' OFS=\"\t\" $FSTAB_FILE"
                log_info "Modifying $FSTAB_FILE using $CMD_AWK" $OK_LOG_CODE
                eval $CMD_AWK > $TMP_FILE 2>&1
                mv -f $TMP_FILE $FSTAB_FILE
                # GET RID OF ,auto|noauto OPTIONS
                CMD_AWK="awk '\$1~\"$vg\"{gsub(\",.*auto *\",\",\",\$4)}1' OFS=\"\t\" $FSTAB_FILE"
                log_info "Modifying $FSTAB_FILE using $CMD_AWK" $OK_LOG_CODE
                eval $CMD_AWK > $TMP_FILE 2>&1
                mv -f $TMP_FILE $FSTAB_FILE
                # GET RID OF OPTIONS ENDING WITH ,
                CMD_AWK="awk '\$1~\"$vg\"{gsub(\", *$\",\"\",\$4)}1' OFS=\"\t\" $FSTAB_FILE"
                log_info "Modifying $FSTAB_FILE using $CMD_AWK" $OK_LOG_CODE
                eval $CMD_AWK > $TMP_FILE 2>&1
                mv -f $TMP_FILE $FSTAB_FILE
                # ADDING noauto OPTION
                CMD_AWK="awk '\$1~\"$vg\"{\$4=\$4\",noauto\"}1' OFS=\"\t\" $FSTAB_FILE"
                log_info "Modifying $FSTAB_FILE using $CMD_AWK" $OK_LOG_CODE
                eval $CMD_AWK > $TMP_FILE 2>&1
                mv -f $TMP_FILE $FSTAB_FILE
        done
}

#
# FUNCTION TO GET PARAMETERS FROM CONFIG FILE
#
# $1 file
# $2 filter

get_conf_parameter () {
        FILE_CONTENT=""
        if [ -f $1 ]
        then
                FILE_CONTENT=`cat $1 | grep $2 | sed -e 's/.*=//g'`
        fi

        echo $FILE_CONTENT
}

#
# FUNCTION TO CONFIGURE NETWORK RESOURCES
#
# $1 APP VIP
# $2 TSAM_NODES WITH NO SPACES AND COMMA SEPARATED

tsam_network_rsrc () {

        IFACES=`ifconfig | grep eth | cut -d ' ' -f 1`
        NETWORK_VIP=`echo $1 | awk -F'.' '{ print $1,$2,$3 }'`
        tokens_network_vip=($NETWORK_VIP)
        SRV_IFACE=""
        SCORE=10000000
        for iface in $IFACES
        do
                iface=`echo $iface | tr -dc '[:print:]'`
                NETWORK_ADDRESS=`ip a show $iface | grep inet | awk -F' ' '{ print \$2 }' | sed -e 's/\/.*//g' | awk -F'.' '{ print $1,$2,$3 }'`
	        tokens_network_address=($NETWORK_ADDRESS)
                TMP_SCORE=0
                for i in {2..0}
                do
			EXP=`echo "2-$i" | bc`
                        POW=`echo "100^($EXP)" | bc`
                        WEIGHT=`echo "${tokens_network_address[$i]} - ${tokens_network_vip[$i]}" | bc | sed -e 's/-//g'`
                        TMP_SCORE=`expr $TMP_SCORE + \( $WEIGHT \* $POW \)`
                done
                # Corollary: I am mentally insane
                if [ $TMP_SCORE -lt $SCORE ]
                then
                        SCORE=$TMP_SCORE
                        SRV_IFACE=$iface
                fi
        done

        # NIC RELATIONSHIP
        CMD_NET_RELATIONSHIP="mkequ $TSAM_NIC_RLTSHIP_NAME IBM.NetworkInterface:"
	NODES_LIST=`echo $2 | tr ',' ' '`
	for node in $NODES_LIST
	do
		CMD_NET_RELATIONSHIP=$CMD_NET_RELATIONSHIP"$SRV_IFACE:$node,"
	done
	CMD_NET_RELATIONSHIP=`echo $CMD_NET_RELATIONSHIP | sed -e 's/.$//g'`
	CMD_NET_RELATIONSHIP=`echo $CMD_NET_RELATIONSHIP | tr -dc '[:print:]'`
	log_info "Creating NIC relationship." $OK_LOG_CODE
	log_info "Executing $CMD_NET_RELATIONSHIP" $OK_LOG_CODE

	eval $CMD_NET_RELATIONSHIP >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Error creating NIC relationship. Aborting." $ERROR_LOG_CODE
		exit 1
	fi

	sleep $DELAY

        # IBM.ServiceIP RESOURCE CREATION
        SRV_MASK=`ifconfig $SRV_IFACE | grep inet | awk -F'Mask:' '{ print $2 }'`

	NODE_NAME_LIST=`echo $2 | sed -e 's/,/","/g' | sed -e 's/$/"}/g' | sed -e 's/^/{"/g'`
        CMD_SERVICEIP_RSRC="mkrsrc IBM.ServiceIP NodeNameList=$NODE_NAME_LIST Name=$TSAM_RSRC_VIP_NAME NetMask=$SRV_MASK IPAddress=$1 ResourceType=1"
	CMD_SERVICEIP_RSRC=`echo $CMD_SERVICEIP_RSRC | tr -dc '[:print:]'`
	log_info "Creating IBM.ServiceIP resource." $OK_LOG_CODE
	log_info "Executinng $CMD_SERVICEIP_RSRC" $OK_LOG_CODE
	eval $CMD_SERVICEIP_RSRC >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Error creating IBM.ServiceIP resource. Aborting." $ERROR_LOG_CODE
		exit 1
	fi
}

#
# FUNCTION TO CONFIGURE IBM.Application RESOURCE
#
# $1 TSAM_NODES WITH NO SPACES AND COMMA SEPARATED

tsam_app-script_rsrc () {

	# CHECKING IF COMMAND FILES EXISTS
	for cmd in "$APP_START_CMD" "$APP_STOP_CMD" "$APP_MONITOR_CMD"
	do
		file=`echo $cmd | sed -e 's/ .*//g'`
		check_file_exists $file
		rc=$?
		if [ $rc -ne 0 ]
		then
			log_info "File $file could not be found. Aborting." $ERROR_LOG_CODE
			exit 1
		fi
	done
        NODE_NAME_LIST=`echo $1 | sed -e 's/,/","/g' | sed -e 's/$/"}/g' | sed -e 's/^/{"/g'`
	RSRC_FILE_CONTENT="PersistentResourceAttributes::\n\t\tName=$TSAM_RSRC_SCRIPT_NAME\n\t\tStartCommand=\"$APP_START_CMD\"\n\t\tStopCommand=\"$APP_STOP_CMD\"\n\t\tMonitorCommand=\"$APP_MONITOR_CMD\"\n\t\tMonitorCommandPeriod=$TSAM_MONITOR_PERIOD\n\t\tMonitorCommandTimeout=$TSAM_MONITOR_TIMEOUT\n\t\tNodeNameList=$NODE_NAME_LIST\n\t\tStartCommandTimeout=$TSAM_START_TIMEOUT\n\t\tStopCommandTimeout=$TSAM_STOP_TIMEOUT\n\t\tUserName=\"root\"\n\t\tResourceType=1"
	`echo -e $RSRC_FILE_CONTENT > $RSRC_FILE`
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Resource file $RSRC_FILE for IBM.Application could not be created. Aborting." $ERROR_LOG_CODE
                exit 1
	fi
	CMD_APPLICATION_RSRC="mkrsrc -f $RSRC_FILE IBM.Application"
	CMD_APPLICATION_RSRC=`echo $CMD_APPLICATION_RSRC | tr -dc '[:print:]'`
	log_info "Creating IBM.Application resource." $OK_LOG_CODE
	log_info "Executing $CMD_APPLICATION_RSRC" $OK_LOG_CODE
	log_info "$RSRC_FILE:\n$RSRC_FILE_CONTENT" $OK_LOG_CODE
	eval $CMD_APPLICATION_RSRC >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Error creating IBM.Application resource. Aborting."  $ERROR_LOG_CODE
                exit 1
	fi
	`rm -f $RSRC_FILE`
}

#
# FUNCTION TO CREATE RESOUCE GROUPS
#

tsam_rsrc_creation() {

	# MAIN RESOURCE GROUP
	CMD_MAIN_RSRC_GROUP="mkrg -l Collocated $TSAM_MAIN_RGROUP"
	log_info "Executing $CMD_MAIN_RSRC_GROUP" $OK_LOG_CODE
	eval $CMD_MAIN_RSRC_GROUP >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Main resource group could not be created. Aborting." $ERROR_LOG_CODE
		exit 1
	fi

	# FILE SYSTEMS RESOURCE GROUP
	CMD_RSRC_GROUP="mkrg -l Collocated $TSAM_FS_RSRC_NAME"
	log_info "Executing $CMD_RSRC_GROUP" $OK_LOG_CODE
	eval $CMD_RSRC_GROUP >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "File systems resource group could not be created. Aborting." $ERROR_LOG_CODE
                exit 1
	fi

	sleep $DELAY

	# ADDING IBM.ServiceIP TO MAIN RESOURCE GROUP
	CMD_ADD_RSRC="addrgmbr -g $TSAM_MAIN_RGROUP IBM.ServiceIP:$TSAM_RSRC_VIP_NAME"
	log_info "Executing $CMD_ADD_RSRC" $OK_LOG_CODE
	eval $CMD_ADD_RSRC >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "IBM.ServiceIP resource could not be added to main resource group. Aborting." $ERROR_LOG_CODE
                exit 1
	fi

        # ADDING IBM.Application TO MAIN RESOURCE GROUP
        CMD_ADD_RSRC="addrgmbr -g $TSAM_MAIN_RGROUP IBM.Application:$TSAM_RSRC_SCRIPT_NAME"
        log_info "Executing $CMD_ADD_RSRC" $OK_LOG_CODE
        eval $CMD_ADD_RSRC >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "IBM.Application resource could not be added to main resource group. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# ADDING FILESYSTEMS RESOURCE GROUP TO MAIN RESOURCE GROUP
        CMD_ADD_RSRC="addrgmbr -g $TSAM_MAIN_RGROUP IBM.ResourceGroup:$TSAM_FS_RSRC_NAME"
        log_info "Executing $CMD_ADD_RSRC" $OK_LOG_CODE
        eval $CMD_ADD_RSRC >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Filesystems resource group could not be added to main resource group. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

}

#
# FUNCTION TO CONFIGURE DEPENDON RELATIONSHIPS
#

tsam_relationships () {
	
	# RELATIONSHIP TO DETECT LINK FAILURE 
	CMD_CREATE_REL="mkrel -p DependsOn -S IBM.ServiceIP:$TSAM_RSRC_VIP_NAME -G IBM.Equivalency:$TSAM_NIC_RLTSHIP_NAME $TSAM_LINK_RLTSHIP_NAME"
	log_info "Executing $CMD_CREATE_REL" $OK_LOG_CODE
	eval $CMD_CREATE_REL >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Error creating depend on relationship. Aborting." $ERROR_LOG_CODE
		exit 1
	fi

	# RELATIONSHIP TO STOP APP IF IP IS NOT CONFIGURED
	CMD_CREATE_REL="mkrel -p DependsOn -S IBM.Application:$TSAM_RSRC_SCRIPT_NAME -G IBM.ServiceIP:$TSAM_RSRC_VIP_NAME $TSAM_SCRIPT_IP_RLTSHIP_NAME"
        log_info "Executing $CMD_CREATE_REL" $OK_LOG_CODE
        eval $CMD_CREATE_REL >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error creating depend on relationship. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# RELATIONSHIP TO STOP APP IF FSs ARE NOT MOUNTED
        CMD_CREATE_REL="mkrel -p DependsOn -S IBM.Application:$TSAM_RSRC_SCRIPT_NAME -G IBM.ResourceGroup:$TSAM_FS_RSRC_NAME $TSAM_SCRIPT_FS_RLTSHIP_NAME"
        log_info "Executing $CMD_CREATE_REL" $OK_LOG_CODE
        eval $CMD_CREATE_REL >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error creating depend on relationship. Aborting." $ERROR_LOG_CODE
                exit 1
        fi
	
	# CREATING RELATIONSHIP BETWEEN MOUNT POINTS, IF NEEDED
	MOUNT_POINTS=`lssam -V | grep AgFileSystem | grep MNT | awk -F'=' '{ print $2 }' | sed -e 's/[ .]*|//g' | sort`
	# STOPPING PEER DOMAIN TO BE ABLE TO MOUNT FILESYSTEMS BY HAND
	`lssam -V > $LSSAM_OUTPUT_FILE`
	cmd_mkrel=''

	# CALCULATING FS DEPENDENCIES
	for FS in $MOUNT_POINTS
	do
        	DEPENDENCY=''
	        DEPENDENCY_SCORE=0
        	for CANDIDATE in $MOUNT_POINTS
	        do
        	        if [ $FS = $CANDIDATE ]
                	then
                        	continue
	                fi
        	        `echo $FS | grep "^$CANDIDATE" > /dev/null 2>&1`
                	rc=$?
	                if [ $rc -eq 0 ]
        	        then
	
        	                CANDIDATE_SCORE=`echo $CANDIDATE | tr '/' ' ' | wc -w`
                	        if [ $CANDIDATE_SCORE -gt $DEPENDENCY_SCORE ]
                        	then
	                                DEPENDENCY_SCORE=$CANDIDATE_SCORE
        	                        DEPENDENCY=$CANDIDATE
                	        fi
	                fi
	        done

		# FOUND DEPENDENCY
        	if [ $DEPENDENCY_SCORE -gt 0 ]
	        then
	                SOURCE_FS_LABEL=`cat $LSSAM_OUTPUT_FILE | grep IBM.AgFileSystem | grep "$FS " | sed -e 's/.*:\(.*\) MNT.*/\1/g'`
                        TARGET_FS_LABEL=`cat $LSSAM_OUTPUT_FILE | grep IBM.AgFileSystem | grep "$DEPENDENCY " | sed -e 's/.*:\(.*\) MNT.*/\1/g'`
                        RLTSHP_NAME=`echo $SOURCE_FS_LABEL | sed -e 's/_rs$/_rel/g'`
                        CMD_RTLSHP="mkrel -p DependsOn -S IBM.AgFileSystem:$SOURCE_FS_LABEL -G IBM.AgFileSystem:$TARGET_FS_LABEL $RLTSHP_NAME"
                        cmd_mkrel=("${cmd_mkrel[@]}" "$CMD_RTLSHP")
                        log_info "Detected DependOn relationship between $FS -> $DEPENDENCY." $OK_LOG_CODE
	        fi
	done

	# CREATING DEPEND ON RELATIONSHIPS BETWEEN FSs
	NUMBER_CMDs=${#cmd_mkrel[@]}
	INDEX=0
	while [ $INDEX -lt $NUMBER_CMDs ]
	do
		CMD_RLTSHP="${cmd_mkrel[$INDEX]}"
		log_info "Creating depend on relationship:" $OK_LOG_CODE
		log_info "Executing $CMD_RLTSHP" $OK_LOG_CODE
		eval $CMD_RLTSHP
		rc=$?
		if [ $rc -ne 0 ]
		then
			log_info "There was some kind of error creating the depend on relationship. Aborting." $ERROR_LOG_CODE
			exit 1
		fi
		let ++INDEX
	done

}

#
# FUNCTION TO CONFIGURE FILESYSTEMS RESOURCES
#

tsam_fs_resources () {

	VGS=`echo $APP_VGS | tr ',' ' '`
	for vg in $VGS
	do
		activating_vg $vg		
		LVS=`lvdisplay | grep $vg | grep LV | awk -F' ' '{ print $3}'`
		for lv in $LVS
		do
			LV_NAME=$(echo $lv | awk -F'/' '{ print $4 }')
	                # CHECK IF THERE IS A /etc/fstab LINE FOR THIS LV
			FSTAB_ENTRY=`grep $LV_NAME /etc/fstab | grep -v '#' > /dev/null 2>&1`
			rc=$?
			if [ $rc -ne 0 ]
			then
				log_info "There is no entry for $lv in /etc/fstab. Aborting." $ERROR_LOG_CODE
				exit 1
			fi
			MOUNT_POINT=`cat /etc/fstab | grep $LV_NAME | grep -v '#' | awk -F' ' '{ print $2 }'`
			# CHECKING IF noauto OPTION IS INCLUDED
			CMD_NOAUTO="cat /etc/fstab | grep $MOUNT_POINT | grep -v '#' | awk -F' ' '{ print \$4 }' | grep noauto > /dev/null 2>&1"
			eval $CMD_NOAUTO
			rc=$?
			if [ $rc -ne 0 ]
			then
                                log_info "$lv entry at /etc/fstab does not include noauto option. Aborting." $ERROR_LOG_CODE
                                exit 1
			fi
			NEW_NAME=$LV_NAME"_rs"
			OLD_NAME=`lsrsrc -s "SysMountPoint='$MOUNT_POINT'" IBM.AgFileSystem | grep "^\s*Name"| uniq | awk -F'"' '{ print $2 }'`
			CMD_CHRSRC="chrsrc -s \"Name='$OLD_NAME'\" IBM.AgFileSystem Name=$NEW_NAME"
			log_info "Executing $CMD_CHRSRC" $OK_LOG_CODE
			eval $CMD_CHRSRC >> $LOG_FILE 2>&1
			rc=$?
			if [ $rc -ne 0 ]
			then
				log_info "Some kind of error happened. Aborting." $ERROR_LOG_CODE
				exit 1
			fi

			sleep $DELAY

			CMD_RESET_RSRC="refrsrc IBM.AgFileSystem"
			eval $CMD_RESET_RSRC
			log_info "Executing $CMD_RESET_RSRC" $OK_LOG_CODE 

			sleep $DELAY
			sleep $DELAY

			# ADD FS TO FILESYSTEM RESOURCE GROUP
			CMD_ADD_FS2RSRC="addrgmbr -g $TSAM_FS_RSRC_NAME IBM.AgFileSystem:$NEW_NAME"
			log_info "Adding $lv to $TSAM_FS_RSRC_NAME" $OK_LOG_CODE
			log_info "Executing $CMD_ADD_FS2RSRC" $OK_LOG_CODE
			eval $CMD_ADD_FS2RSRC >> $LOG_FILE 2>&1
			rc=$?
			if [ $rc -ne 0 ]
			then
				log_info "$lv could not be added to resource group $TSAM_FS_RSRC_NAME. Aborting." $ERROR_LOG_CODE
				exit 1
			fi

			sleep $DELAY
		done

		# REMOVING LOCKING
		CMD_CHRSRC="chrsrc -s \"Name='$vg'\" IBM.VolumeGroup DeviceLockMode=0"
		log_info "Removing volume group $vg locking." $OK_LOG_CODE
		log_info "Executing $CMD_CHRSRC" $OK_LOG_CODE
		eval $CMD_CHRSRC >> $LOG_FILE 2>&1
		rc=$?
		if [ $rc -ne 0 ]	
		then
		                log_info "Some kind of error happened trying to remove volume group $vg locking. Aborting." $ERROR_LOG_CODE
                                exit 1
		fi
		VG_DISKS=`pvscan 2> /dev/null | grep $vg | cut -d ' ' -f 4 | sed -e 's/.$//g'`
		for disk in $VG_DISKS
		do
			CMD_CHRSRC="chrsrc -s \"DeviceName='$disk'\" IBM.Disk DeviceLockMode=0"
			log_info "Removing disk $disk locking." $OK_LOG_CODE
			log_info "Executing $CMD_CHRSRC" $OK_LOG_CODE
			eval $CMD_CHRSRC >> $LOG_FILE 2>&1
			rc=$?
                        if [ $rc -ne 0 ]
                        then
                                log_info "Some kind of error happened trying to remove disk $disk locking. Aborting." $ERROR_LOG_CODE
                                exit 1
                        fi
		done
	done

}

###########
# MAIN () #
###########

# GETTING TSAM INFORMATION
TSAM_NODES=$(get_conf_parameter $CNF_FILE "TSAM_NODES")
TSAM_MAIN_RGROUP=$(get_conf_parameter $CNF_FILE "TSAM_MAIN_RGROUP")
TSAM_MONITOR_PERIOD=$(get_conf_parameter $CNF_FILE "TSAM_MONITOR_PERIOD")
TSAM_MONITOR_TIMEOUT=$(get_conf_parameter $CNF_FILE "TSAM_MONITOR_TIMEOUT")
TSAM_START_TIMEOUT=$(get_conf_parameter $CNF_FILE "TSAM_START_TIMEOUT")
TSAM_STOP_TIMEOUT=$(get_conf_parameter $CNF_FILE "TSAM_STOP_TIMEOUT")

# GETTING APP INFORMATION
APP_VIP=$(get_conf_parameter $CNF_FILE "APP_VIP")
APP_START_CMD=$(get_conf_parameter $CNF_FILE "APP_START_CMD")
APP_STOP_CMD=$(get_conf_parameter $CNF_FILE "APP_STOP_CMD")
APP_MONITOR_CMD=$(get_conf_parameter $CNF_FILE "APP_MONITOR_CMD")
APP_VGS=$(get_conf_parameter $CNF_FILE "APP_VGS")

LOG_FILE="/var/log/tsam-$TSAM_MAIN_RGROUP-conf.log"

#####################
# TSAM INSTALLATION #
#####################

MD5SUM=`md5sum $0 | awk '{ print $1}'`

log_info "Starting configuration of $TSAM_MAIN_RGROUP resource group." $OK_LOG_CODE
log_info "Script version $SCRIPT_VERSION" $OK_LOG_CODE
log_info "Script $0 md5sum $MD5SUM" $OK_LOG_CODE

if [ $# -ne 1 ]
then
	log_info "Wrong number of arguments provided. Aborting." $ERROR_LOG_CODE
	exit 1
fi

# INCLUDING noauto OPTION TO /etc/fstab

# TO LOCAL NODE
fstab_mod $APP_VGS 

# TO OTHER NODES
NODES=`echo $TSAM_NODES | tr ',' ' '`
for node in $NODES
do
        if [ $node != $LOCAL_HOSTNAME ]
        then
                CMD_SSH="scp /etc/fstab root@$node:/etc/fstab"
		log_info "Copying /etc/fstab to $node" $OK_LOG_CODE
		eval $CMD_SSH >> $LOG_FILE 2>&1
		rc=$?
		if [ $rc -ne 0 ]
                then
                	log_info "/etc/fstab could not be copied to $node. Aborting." $ERROR_LOG_CODE
                        exit 1
                fi
        fi
done

####################
# CONFIGURING TSAM #
####################

# CREATING IBM.ServiceIP RESOURCE AND SERVICE NIC RELATIONSHIP
tsam_network_rsrc $APP_VIP $TSAM_NODES

sleep $DELAY

# CREATING IBM.Application RESOURCE
tsam_app-script_rsrc $TSAM_NODES

sleep $DELAY

# CREATING RESOURCE GROUPS
tsam_rsrc_creation 

sleep $DELAY

# CREATING IBM.AgFileSystem RESOURCES
tsam_fs_resources

sleep $DELAY

# CREATING DEPEND ON RELATIONSHIPS
tsam_relationships

sleep $DELAY

# FINISHING
log_info "Installation finished successfully. :-O" $OK_LOG_CODE

exit 0
