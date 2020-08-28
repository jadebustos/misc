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
LOG_FILE="/var/log/tsam-installation.log"
LOCAL_HOSTNAME=`hostname`
DELAY=2

TSAM_UNINSTALL_BIN="/opt/IBM/tsamp/sam/uninst/uninstallSAM"
TRANSFER_PATH="/tmp/"
SRV_IFACE="eth1"

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
# FUNCTION TO CHECK PREREQUISITES
#
# $1 NODES

check_node_prereq () {
	for node in $*
	do
		# CHECK FOR PROPER DNS RESOLUTION
		CMD_DNS="host $node"
		log_info "Testing $node DNS name resolution." $OK_LOG_CODE
		log_info "Executing $CMD_DNS" $OK_LOG_CODE
		eval $CMD_DNS >> $LOG_FILE 2>&1
		rc=$?
		if [ $rc -ne 0 ]
		then
			log_info "Hostname $node can't be resolved. Aborting." $ERROR_LOG_CODE 
			exit 1
		fi
		# CHECK TO GET NODES
		CMD_PING="ping -c 4 $node"
		log_info "Testing if $node is pingable." $OK_LOG_CODE
		log_info "Executing $CMD_PING" $OK_LOG_CODE
		eval $CMD_PING >> $LOG_FILE 2>&1
                rc=$?
                if [ $rc -ne 0 ]
                then
                        log_info "Host $node can't be reached using ping. Aborting." $ERROR_LOG_CODE
			exit 1
                fi
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
# FUNCTION TO UNINSTALL TSAM
#
# $1 NODE WHERE TO UNINSTALL TSAM
#

uninstall_tsam () {
        # STOPPING PEER DOMAIN
	CMD_CHECKING_PEER_DOMAIN="ssh -q -t root@$1 lsrpdomain | grep Online > /dev/null 2>&1"
	log_info "Checking if there is some peer domain online on $1." $OK_LOG_CODE
	$($CMD_CHECKING_PEER_DOMAIN)
	rc=$?
	if [ $rc -eq 0 ]
	then
		CMD_SSH="ssh -q -t root@$1"
		CMD_GET_PEER_DOMAIN_NAME=$CMD_SSH" lsrpdomain | grep Online | cut -d ' ' -f 1 | tr -dc '[:print:]'"
		DOMAIN_NAME=$($CMD_GET_PEER_DOMAIN_NAME)
		rc=$?
		if [ $rc -ne 0 ]
		then
			log_info "Online peer domain detected but its name could not be determined. Aborting." $ERROR_LOG_CODE
			exit 1
		fi
		log_info "Found $DOMAIN_NAME peer domain online." $OK_LOG_CODE
		log_info "Forcing $DOMAIN_NAME peer domain to stop on $1." $OK_LOG_CODE
		stop_peer_domain $DOMAIN_NAME
	fi

	# UNINSTALLING SOFTWARE 
	CMD_UNINSTALL_TSAM="ssh -q -t root@$1 $TSAM_UNINSTALL_BIN"
	log_info "Uninstalling TSAM from $1." $OK_LOG_CODE
	log_info "Executing $CMD_UNINSTALL_TSAM" $OK_LOG_CODE
	$($CMD_UNINSTALL_TSAM >> $LOG_FILE 2>&1)
	rc=$?
        if [ $rc -ne 0 ]
        then
        	log_info "TSAM could not be uninstalled from $1. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# RESTORING ORIGINAL /etc/fstab
	TIMESTAMP=`head -n 1 /etc/fstab | sed -e 's/^# *//g'`
	SRC_RESTORE="/etc/fstab-"$TIMESTAMP
	if [ -f $SRC_RESTORE ]
	then
		scp -q $SRC_RESTORE root@$1:/etc/fstab
		rc=$?
		if [ $rc -eq 0 ]
		then
			log_info "Restored $SRC_RESTORE to /etc/fstab on node $1." $OK_LOG_CODE
		else
			log_info "$SRC_RESTORE could not be restored /etc/fstab on node $1." $OK_LOG_CODE
		fi
	fi

        log_info "TSAM successfully uninstalled from $1." $OK_LOG_CODE
	
}

#
# FUNCTION TO INSTALL TSAM
#
# $1 NODE WHERE TO INSTALL TSAM
# $2 TSAM TGZ PATH
# $3 TSAM LICENSE FILE
#

install_tsam () {
	# CHECKING PACKAGES NEEDED BY TSAM
	TSAM_INSTALL_PREREQS="ksh perl libstdc++.i686 libstdc++.x86_64 compat-libstdc++-33.x86_64 pam.i686 perl-Time-HiRes"
	for rpm in $TSAM_INSTALL_PREREQS
	do
		CMD_RPM="ssh -t -q root@$1 yum list installed | grep $rpm > /dev/null"
		eval $CMD_RPM
		rc=$?
		if [ $rc -eq 0 ]
		then
			continue
		fi
		CMD_YUM="ssh -t -q root@$1 yum install --assumeyes $rpm >> $LOG_FILE 2>&1"
                log_info "Package $rpm not installed in $1." $OK_LOG_CODE
                log_info "Executing $CMD_YUM" $OK_LOG_CODE
		eval $CMD_YUM
	        rc=$?
        	if [ $rc -ne 0 ]
	        then
        	        log_info "Package $rpm could not be installed to $1. Aborting." $ERROR_LOG_CODE
                	exit 1
	        fi
	done

	# CHECKING IF TSAM IS INSTALLED
	CMD_CHECK_TSAM_INSTALL="ssh -q -t root@$1 ls $TSAM_UNINSTALL_BIN > /dev/null 2>&1"
	eval $CMD_CHECK_TSAM_INSTALL
	rc=$?
	if [ $rc -eq 0 ]
	then
		uninstall_tsam $1
	fi

	# COPYING TSAM FILES	
	CMD_COPY="scp -q $2 root@$1:$TRANSFER_PATH"
	log_info "Executing $CMD_COPY" $OK_LOG_CODE
	eval $CMD_COPY >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "TSAM tgz could not be copied to $1. Aborting." $ERROR_LOG_CODE
		exit 1
	fi
	log_info "$TSAM_FILE sucessfully copied to $1." $OK_LOG_CODE

	# EXTRACTING TSAM FILES
	log_info "Extracting $TSAM_FILE in $1:$TRANSFER_PATH." $OK_LOG_CODE
	CMD_UNTAR="ssh -q root@$1 tar zxf $TRANSFER_PATH$TSAM_FILE -C $TRANSFER_PATH"
	log_info "Executing $CMD_UNTAR" $OK_LOG_CODE
	eval $CMD_UNTAR >> $LOG_FILE 2>&1
	rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "TSAM tgz could not be extracted to $1:$TRANFER_PATH. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# COPYING LICENSE FILE
	if [ ! -f $TSAM_LICENSE_FILE ]
	then
		log_info "TSAM license file could not be found. Aborting." $ERROR_LOG_CODE
		exit 1
	fi
	CMD_COPY="scp -q $TSAM_LICENSE_FILE root@$1:$TRANSFER_PATH$TSAM_UNTAR_DIR/license"
	log_info "Executing $CMD_COPY" $OK_LOG_CODE
	$($CMD_COPY)
	rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "TSAM license file could not be copied to $1:$TRANSFER_PATH$TSAM_UNTAR_DIR. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# INSTALLING TSAM
	
	# DELETE TSAM ENVIRONMENT VARIABLES
	CMD_TSAM_PRE_ENV="ssh -q root@$1 sed -i '/CT_MANAGEMENT_SCOPE/d' /root/.bash_profile"
        log_info "Executing $CMD_TSAM_PRE_ENV" $OK_LOG_CODE
	$($CMD_TSAM_PRE_ENV)
	rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Could not be erased TSAM enviroment variables from /root/.bash_profile in $1. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# INCLUDE TSAM ENVIRONMENT VARIABLES
        tsam_env=("\"# TSAM CT_MANAGEMENT_SCOPE\"" "\"CT_MANAGEMENT_SCOPE=2\"" "\"export CT_MANAGEMENT_SCOPE\"")
        for line in ${!tsam_env[@]}
        do
                CMD_TSAM_ENV="ssh -q root@$1 echo ${tsam_env[$line]} >> /root/.bash_profile"
	        log_info "Executing $CMD_TSAM_ENV" $OK_LOG_CODE
	        $($CMD_TSAM_ENV)
        	rc=$?
	        if [ $rc -ne 0 ]
        	then
                	log_info "Could not be configured TSAM enviroment variables in /root/.bash_profile in $1. Aborting." $ERROR_LOG_CODE
	                exit 1
       		 fi
        done

	# INSTALLING BINARIES
	TSAM_INSTALL_BIN="$TRANSFER_PATH$TSAM_UNTAR_DIR/installSAM"
	CMD_INSTALL="ssh -q -t root@$1 $TSAM_INSTALL_BIN --silent"
	log_info "Executing $CMD_INSTALL" $OK_LOG_CODE
	eval $CMD_INSTALL >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "TSAM installation in node $1 was unsuccessful. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

	# DELETING BINARIES
	CMD_DEL_BIN="ssh -q -t root@$1 rm -Rf /tmp/$2"
	log_info "Executing $CMD_DEL_BIN" $OK_LOG_CODE
        eval $CMD_DEL_BIN >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Removing /tmp/$2 in node $1 was unsuccessful." $NON_FATAL_ERROR_LOG_CODE
        fi

        CMD_DEL_BIN="ssh -q -t root@$1 rm -Rf /tmp/$TSAM_UNTAR_DIR"
        log_info "Executing $CMD_DEL_BIN" $OK_LOG_CODE
        eval $CMD_DEL_BIN >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Removing /tmp/$TSAM_UNTAR_DIR in node $1 was unsuccessful." $NON_FATAL_ERROR_LOG_CODE
        fi
}

#
# FUNCTION TO CONFIGURE TSAM
#

tsam_setup() {
	
	CMD_SSH="ssh -q -t root@$LOCAL_HOSTNAME"
	# PREPARING NODES
	NODE_LIST=`echo $TSAM_NODES | tr ',' ' '`
	for node in $NODE_LIST
	do
		CMD_PREP_NODE="ssh -q -t root@$node preprpnode $NODE_LIST"
		log_info "Preparing node $node to set up" $OK_LOG_CODE
		log_info "Executing $CMD_PREP_NODE" $OK_LOG_CODE
		eval $CMD_PREP_NODE  >> $LOG_FILE 2>&1
		rc=$?
		if [ $rc -ne 0 ]
		then
			log_info "Error executing preprpnode in $node. Aborting." $ERROR_LOG_CODE
                        exit 1
		fi
	done

	# CREATING PEER DOMAIN
	CMD_CREATE_PEER_DOMAIN="mkrpdomain $TSAM_PEER_DOMAIN $NODE_LIST"
	log_info "Creating peer domain." $OK_LOG_CODE
	log_info "Executing $CMD_CREATE_PEER_DOMAIN" $OK_LOG_CODE
	eval $CMD_CREATE_PEER_DOMAIN
	rc=$?
	if [ $rc -ne 0 ]
	then
		log_info "Error creating the peer domain." $ERROR_LOG_CODE
		exit 1
	fi

	# ACTIVATING PEER DOMAIN
	sleep 5
	start_peer_domain $TSAM_PEER_DOMAIN
}

#
# FUNCTION TO START PEER DOMAIN
#
# $1 PEER DOMAIN NAME

start_peer_domain () {
        DOMAIN_NAME=$1
        CMD_ACTIVATING_PEER_DOMAIN="startrpdomain $DOMAIN_NAME"
        log_info "Starting peer domain." $OK_LOG_CODE
        log_info "Executing $CMD_ACTIVATING_PEER_DOMAIN" $OK_LOG_CODE
        eval $CMD_ACTIVATING_PEER_DOMAIN >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error starting the peer domain $DOMAIN_NAME." $ERROR_LOG_CODE
                exit 1
        fi
        CMD_WAITING_PEER_DOMAIN_ONLINE="lsrpdomain | grep Online > /dev/null 2>&1"
        eval $CMD_WAITING_PEER_DOMAIN_ONLINE
        rc=$?
        COUNTER=0
        SECONDS=2
        ITERATIONS=20
        while [ $rc -ne 0 ]
        do
                sleep $SECONDS
                eval $CMD_WAITING_PEER_DOMAIN_ONLINE
                rc=$?
                # AFTER ITERATIONS EXIT
                if [ $COUNTER -eq $ITERATIONS ]
                then
                        INTERVAL=`expr $SECONDS \* $ITERATIONS`
                        log_info "Peer domain $DOMAIN_NAME is not Online after $INTERVAL seconds. Aborting" $ERROR_LOG_CODE
                        exit 1
                fi
                log_info "Waiting $DOMAIN_NAME to be brought online." $OK_LOG_CODE
                let ++COUNTER
        done

        log_info "$DOMAIN_NAME is online." $OK_LOG_CODE

        sleep $DELAY

}

#
# FUNCTION TO STOP PEER DOMAIN
#
# $1 PEER DOMAIN NAME

stop_peer_domain () {
        DOMAIN_NAME=$1
        CMD_STOPPING_PEER_DOMAIN="stoprpdomain -f $DOMAIN_NAME"
        log_info "Executing $CMD_STOPPING_PEER_DOMAIN" $OK_LOG_CODE
        eval $CMD_STOPPING_PEER_DOMAIN >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
               log_info "$DOMAIN_NAME could not be brought offline. Aborting." $ERROR_LOG_CODE
               exit 1
        fi
        # WAITING TO BE OFFLINE
        CMD_WAITING_PEER_DOMAIN_OFFLINE="lsrpdomain | grep Offline > /dev/null 2>&1"
        eval $CMD_WAITING_PEER_DOMAIN_OFFLINE
        rc=$?
        COUNTER=0
        SECONDS=2
        ITERATIONS=20
        while [ $rc -ne 0 ]
        do
                sleep $SECONDS
                eval $CMD_WAITING_PEER_DOMAIN_OFFLINE
                rc=$?
                # AFTER ITERATIONS EXIT
                if [ $COUNTER -eq $ITERATIONS ]
                then
                        INTERVAL=`expr $SECONDS \* $ITERATIONS`
                        log_info "$DOMAIN_NAME peer domain is not Offline after $INTERVAL seconds. Aborting." $ERROR_LOG_CODE
                        exit 1
                fi
                log_info "Waiting $DOMAIN_NAME peer domain to be brought offline." $OK_LOG_CODE
                let ++COUNTER
        done
        log_info "$DOMAIN_NAME peer domain is offline." $OK_LOG_CODE
}

#
# FUNCTION TO CONFIGURE TSAM TIEBREAKER
#

tsam_tiebreaker () {
        if [ $TSAM_TIEBREAKER = "Operator" ]
        then
                log_info "Network tiebreaker is Operator." $OK_LOG_CODE
                return
        fi
        CMD_TIEBREAKER="mkrsrc IBM.TieBreaker Type=\"EXEC\" Name=\"tiebreaker_NET\" DeviceInfo='PATHNAME=/usr/sbin/rsct/bin/samtb_net Address=$TSAM_TIEBREAKER Log=1' PostReserveWaitTime=30;"
        CMD_ENABLE_TIEBREAKER="chrsrc -c IBM.PeerNode OpQuorumTieBreaker=\"tiebreaker_NET\""
        log_info "Creating network tiebreaker." $OK_LOG_CODE
        log_info "Executing $CMD_TIEBREAKER" $OK_LOG_CODE
        eval $CMD_TIEBREAKER
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Network tiebreaker could not be created. Aborting." $ERROR_LOG_CODE
                exit 1
        fi
        log_info "Activating network tiebreaker." $OK_LOG_CODE
        log_info "Executing $CMD_ENABLE_TIEBREAKER" $OK_LOG_CODE
        eval $CMD_ENABLE_TIEBREAKER
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Network tiebreaker could not be activated. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

}

#
# FUNCTION TO CONFIGURE HEARTBEAT DISK
#

tsam_hb_disk () {

	# COMMUNICATION GROUP
        CMD_CG_CREATION="mkcomg -M 2 HB_disk"
        log_info "Heartbeat disk communication group creation." $OK_LOG_CODE
        log_info "Executing $CMD_CG_CREATION" $OK_LOG_CODE
        eval $CMD_CG_CREATION >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Heartbeat disk communication group could not be created. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

        # LVID
        HB_DISK_LVID=`lvdisplay /dev/$HB_VG_NAME/$HB_LV_NAME | grep "UUID" | awk -F' ' '{ print $3 }'`
        CMD_HBDISK_CREATION="mkrsrc IBM.HeartbeatInterface Name="diskhb" DeviceInfo=\"LVID=$HB_DISK_LVID\" MediaType=2 NodeNameList={$TSAM_NODES} CommGroup=\"HB_disk\""
        log_info "Heartbeat disk creation." $OK_LOG_CODE
        log_info "Executing $CMD_HBDISK_CREATION" $OK_LOG_CODE
        eval $CMD_HBDISK_CREATION >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Heartbeat disk could not be created. Aborting." $ERROR_LOG_CODE
                exit 1
        fi

}

#
# FUNCTION TO DETECT NETWORK CONNECTIVITY LOST WITHOUT NETWORK LINK LOST
#

l3_network_issue () {
	NETMON_FILE="/var/ct/cfg/netmon.cf"
	GATEWAY_IP=`ip ro | grep default | awk -F' ' '{ print $3 }'`

	log_info "Configuring IP addresses that have to be checked to be reachable." $OK_LOG_CODE
	for node in `echo $TSAM_NODES | tr ',' ' '`
	do
		CMD_SSH="ssh -q -t root@$node "
		# GATEWAY IP
		CMD_NETMON=$CMD_SSH" \"echo \"!REQD $SRV_IFACE $GATEWAY_IP\" > $NETMON_FILE\""
		log_info "Adding gateway to $node." $OK_LOG_CODE
		log_info "Executing $CMD_NETMON" $OK_LOG_CODE
		eval $CMD_NETMON >> $LOG_FILE 2>&1
	        rc=$?
        	if [ $rc -ne 0 ]
	        then
        	        log_info "Gateway could not be added to $NETMON_FILE on $node. Aborting." $ERROR_LOG_CODE
                	exit 1
	        fi

		# OTHER NODES IPs
		for node2 in `echo $TSAM_NODES | tr ',' ' '`
		do
			if [ $node = $node2 ]
			then
				continue
			fi
			
			NODE2_IP=`host $node2 | sed -e 's/.*address //g'`
			CMD_NETMON=$CMD_SSH" \"echo \"!REQD $SRV_IFACE $NODE2_IP\" >> $NETMON_FILE\""
	                log_info "Adding $node2 ip to $node." $OK_LOG_CODE
	                log_info "Executing $CMD_NETMON" $OK_LOG_CODE
        	        eval $CMD_NETMON >> $LOG_FILE 2>&1
                	rc=$?
	                if [ $rc -ne 0 ]
        	        then
                	        log_info "$node2 ip could not be added to $NETMON_FILE on $node. Aborting." $ERROR_LOG_CODE
                        	exit 1
	                fi

		done		
	done
}

#
#
#

removing_hb_disk_elements () {

LVS=`lvs | grep $HB_VG_NAME | awk '{ print $1 }'`

# REMOVING ALL LOGICAL VOLUMES, JUST IN CASE
for lv in `echo $LVS`
do
	CMD_LVREMOVE="lvremove -f /dev/$HB_VG_NAME/$lv"
	log_info "Executing $CMD_LVREMOVE" $OK_LOG_CODE
	eval $CMD_LVREMOVE >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -eq 0 ]
	then
		log_info "Logical volume /dev/$HB_VG_NAME/$lv was successfully removed." $OK_LOG_CODE
	else
		log_info "Logical volume /dev/$HB_VG_NAME/$lv could not be removed." $ERROR_LOG_CODE
		exit 1
	fi
done

# WAITING
sleep 2

# REMOVING VOLUME GROUP
`vgdisplay $HB_VG_NAME > /dev/null`
rc=$?
if [ $rc -eq 0 ]
then
	VG_DEV=`pvscan | grep $HB_VG_NAME | awk -F' ' '{print $2}'`
	CMD_VGREMOVE="vgremove -f $HB_VG_NAME"
	log_info "Executing $CMD_VGREMOVE" $OK_LOG_CODE
	eval $CMD_VGREMOVE >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -eq 0 ]
	then
		log_info "Volume Group $HB_VG_NAME was successfully removed." $OK_LOG_CODE
	else
		log_info "Volume Group $HB_VG_NAME could not be removed." $ERROR_LOG_CODE
		exit 1
	fi
	# WAITING
	sleep 2
	# REMOVING PHYSICAL VOLUME
	CMD_PVREMOVE="pvremove $VG_DEV"
	log_info "Executing $CMD_PVREMOVE" $OK_LOG_CODE
	eval $CMD_PVREMOVE >> $LOG_FILE 2>&1
	rc=$?
	if [ $rc -eq 0 ]
	then
		log_info "Physical volume $HD_DISK_DEV was successfully removed." $OK_LOG_CODE
	else
		log_info "Physical volume $HD_DISK_DEV could not be removed." $ERROR_LOG_CODE
		exit 1
	fi
fi

# REMOVING PARTITIONS, IF ANY
PARTITION_NUMBER=`parted -s $TSAM_HB_DISK print | tail -n +7 | awk -F' ' '{print $1}' | sed -e '/^$/d' | wc -l`
if [ $PARTITION_NUMBER -gt 1 ]
then
	PARTITIONS=`parted -s $TSAM_HB_DISK print | tail -n +7 | awk -F' ' '{print $1}' | sed -e '/^$/d'`
	for $item in `echo $PARTITIONS`
	do
		CMD_PARTITIONREMOVE="parted -s $TSAM_HB_DISK rm $item"
	        log_info "Executing $CMD_PARTITIONREMOVE" $OK_LOG_CODE
        	eval $CMD_PARTITIONREMOVE >> $LOG_FILE 2>&1
	        rc=$?
        	if [ $rc -eq 0 ]
	        then
        	        log_info "Partition $item in /dev/$TSAM_HB_DISK was successfully removed." $OK_LOG_CODE
	        else
        	        log_info "Partition $item in /dev/$TSAM_HB_DISK could not be removed." $ERROR_LOG_CODE
			exit 1
		fi
		# WAITING
		sleep 2
	done
fi

# WAITING
sleep 2
}

#
# FUNCTION TO CREATE HB DISK, IT STARTS THE PEER DOMAIN, IF PRESENT TO GET HB DISK INFO
#

create_hb_disk_vg () {

	# CHECK IF HB DISK EXISTS AND REMOVE IT
	# REMOVING HEARTBEAT DISK
        PEER_DOMAIN_NAME=`lsrpdomain | grep -v OpState | awk -F' ' '{print $1}'`
        PEER_STATE=`lsrpdomain | grep -v OpState | awk -F' ' '{print $2}'`
        rc=1
        if [ $PEER_DOMAIN_NAME ]
        then
        	log_info "Trying to start $PEER_DOMAIN_NAME to get heartbeat disk info." $OK_LOG_CODE
                start_peer_domain $PEER_DOMAIN_NAME
                rc=$?
        fi
	if [ $rc -eq 0 ]
	then
		log_info "$PEER_DOMAIN_NAME was successfully started." $OK_LOG_CODE
		# GETTNG HEARTBEAT DISK INFO IF ANY
		CHECK_HB_COMG=`lscomg | grep \(Disk\)`
		rc=$?
		if [ $rc -eq 0 ]
		then
			HB_COMG_NAME=`lscomg | grep \(Disk\) | awk -F' ' '{print $1}'`
			HB_IFACE_NAME=`lsrsrc IBM.HeartbeatInterface | grep "Name " | uniq | awk -F'"' '{print $2}'`
			HB_DISK_ID=`lscomg -i $HG_COMG_NAME | grep Disk | awk '{ print $3 }' | uniq | sed -e 's/=/='\''/'` 
			HD_DISK_DEV=`lsrsrc -s "'$HB_DISK_PVID'" IBM.LogicalVolume | grep DeviceName | uniq | grep -v \"\" | awk -F'"' '{print $2}'`
			if [ -b $HD_DISK_DEV ]
			then
        			CMD_HB_IFACE_DISABLE="chrsrc -s \"Name='$HB_IFACE_NAME'\" IBM.HeartbeatInterface HeartbeatActive=0"
                		log_info "Executing $CMD_HB_IFACE_DISABLE" $OK_LOG_CODE
		                eval $CMD_HB_IFACE_DISABLE >> $LOG_FILE 2>&1
        		        CMD_RMRSC_HB="rmrsrc -s \"Name='$HB_IFACE_NAME'\" IBM.HeartbeatInterface"
                		log_info "Executing $CMD_RMRSC_HB" $OK_LOG_CODE
	                	eval $CMD_RMRSC_HB >> $LOG_FILE 2>&1
	        	        rc=$?
        	        	if [ $rc -eq 0 ]
	        	        then
	        	        	log_info "$HB_IFACE_NAME heartbeat interface was removed." $OK_LOG_CODE
        	        	        CMD_RMCOMG="rmcomg -V $HB_COMG_NAME"
                	        	log_info "Executing $CMD_RMCOMG" $OK_LOG_CODE
	                	        eval $CMD_RMCOMG >> $LOG_FILE 2>&1
        	                	rc=$?
	                	        if [ $rc -ne 0 ]
        	                	then
						log_info "$HB_COMG_NAME communication group could not be removed." $ERROR_LOG_CODE
						log_info "Remove it manually and try it again." $ERROR_LOG_CODE
						exit 1
	        	                fi
				else
					log_info "$HB_IFACE_NAME heartbeat interface could not be removed." $ERROR_LOG_CODE
					log_info "Remove it manually and try it again." $ERROR_LOG_CODE
					exit 1
				fi
			fi
		fi
		# STOPPING THE PEER DOMAIN
		log_info "Trying to stop $PEER_DOMAIN_NAME." $OK_LOG_CODE
	        stop_peer_domain $PEER_DOMAIN_NAME
		rc=$?
		if [ $rc -ne 0 ]
		then
			log_info "$PEER_DOMAIN_NAME could not be stopped." $ERROR_LOG_CODE
			exit 1
		fi
	else
                log_info "$PEER_DOMAIN_NAME could not be started so no heartbeat information available on previous installation." $OK_LOG_CODE
        fi

	# REMOVING HB DISK ELEMENTS
	removing_hb_disk_elements

	# CREATING DISK PARTITION
        CMD_VGCREATE="parted -s $TSAM_HB_DISK mklabel msdos"
        log_info "Creating vg to store a lv for heartbeat disk." $OK_LOG_CODE
        log_info "Executing $CMD_VGCREATE" $OK_LOG_CODE
        eval $CMD_VGCREATE >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error labeling on disk $TSAM_HB_DISK." $ERROR_LOG_CODE
                exit 1
        fi
	# WAITING
	sleep 2
	# CREATING VOLUME GROUP
        CMD_VGCREATE="parted -s $TSAM_HB_DISK mkpart primary 2048s 100%"
        log_info "Executing $CMD_VGCREATE" $OK_LOG_CODE
        eval $CMD_VGCREATE >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error creating partition on disk $TSAM_HB_DISK." $ERROR_LOG_CODE
                exit 1
        fi
	# WAITING
	sleep 2
        CMD_VGCREATE="parted -s $TSAM_HB_DISK set 1 lvm on"
        log_info "Executing $CMD_VGCREATE" $OK_LOG_CODE
        eval $CMD_VGCREATE >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error changing type to 8e on disk $TSAM_HB_DISK." $ERROR_LOG_CODE
                exit 1
        fi
	# WAITING
	sleep 2
        CMD_VGCREATE="pvcreate "$TSAM_HB_DISK"1"
        log_info "Executing $CMD_VGCREATE" $OK_LOG_CODE
        eval $CMD_VGCREATE >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error creating PV on disk $TSAM_HB_DISK." $ERROR_LOG_CODE
                exit 1
        fi
	# WAITING 
	sleep 2
        CMD_VGCREATE="vgcreate vgHBdisk "$TSAM_HB_DISK"1"
        log_info "Executing $CMD_VGCREATE" $OK_LOG_CODE
        eval $CMD_VGCREATE >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error creating VG on disk $TSAM_HB_DISK." $ERROR_LOG_CODE
                exit 1
        fi
	# WAITING
	sleep 2
	# CREATING LOGICAL VOLUME
        CMD_LVCREATE="lvcreate -L"$TSAM_HB_SIZE"m -n $HB_LV_NAME $HB_VG_NAME"
        log_info "Executing $CMD_LVCREATE" $OK_LOG_CODE
        eval $CMD_LVCREATE >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error creating LV on VG $HB_VG_NAME." $ERROR_LOG_CODE
                exit 1
        fi
}

###########
# MAIN () #
###########

# GETTING TSAM INFORMATION
TSAM_FILE=$(get_conf_parameter $CNF_FILE "TSAM_BIN")
TSAM_UNTAR_DIR=`tar tf $TSAM_FILE | grep -v ".rpm" | awk -F'/' '{ print $1 }' | uniq`
TSAM_NODES=$(get_conf_parameter $CNF_FILE "TSAM_NODES")
TSAM_LICENSE_FILE=$(get_conf_parameter $CNF_FILE "TSAM_LICENSE")
TSAM_PEER_DOMAIN=$(get_conf_parameter $CNF_FILE "TSAM_PEERDOMAIN")
TSAM_TIEBREAKER=$(get_conf_parameter $CNF_FILE "TSAM_TIEBREAKER")
TSAM_HB_DISK=$(get_conf_parameter $CNF_FILE "TSAM_HB_DISK")
TSAM_HB_SIZE=$(get_conf_parameter $CNF_FILE "TSAM_HB_SIZE")

#####################
# TSAM INSTALLATION #
#####################
HB_VG_NAME='vgHBdisk'
HB_LV_NAME=$TSAM_PEER_DOMAIN"_lv"

#########################
# STARTING INSTALLATION #
#########################

MD5SUM=`md5sum $0 | awk '{ print $1}'`

log_info "Starting new installation." $OK_LOG_CODE
log_info "Script version $SCRIPT_VERSION" $OK_LOG_CODE
log_info "Script $0 md5sum $MD5SUM" $OK_LOG_CODE

if [ $# -ne 1 ]
then
	log_info "Wrong number of arguments provided. Aborting." $ERROR_LOG_CODE
	exit 1
fi

# CHECKING PREREQS
check_node_prereq `echo $TSAM_NODES | tr ',' ' '`

# CREATING VG AND LV FOR DISK HEARTBEATING ON LOCAL NODE
create_hb_disk_vg

# REBOOTING OTHER NODES
for i in `echo $TSAM_NODES | sed -e 's/,/ /g'`
do
        if [ $i = $LOCAL_HOSTNAME ]
        then
                continue
        fi
        CMD_SSH="ssh -q -t root@$i reboot"
        log_info "Rebooting $i." $OK_LOG_CODE
        log_info "Executing $CMD_SSH on $i." $OK_LOG_CODE
        eval $CMD_SSH >> $LOG_FILE 2>&1
        rc=$?
        if [ $rc -ne 0 ]
        then
                log_info "Error rebooting $i." $ERROR_LOG_CODE
                exit 1
        fi
done

SLEEP_TIME=20
RETRY_TIME=300

# WAITING NODES TO BOOT
for i in `echo $TSAM_NODES | sed -e 's/,/ /g'`
do
	TIME=0
        if [ $i = $LOCAL_HOSTNAME ]
        then
                continue
        fi
        CMD_SSH="ssh -q -t root@$i ls"
        rc=1
        while [ $rc -ne 0 ]
        do
                log_info "Waiting $SLEEP_TIME seconds to check if $i boots." $OK_LOG_CODE
                sleep $SLEEP_TIME
                TIME=`echo "$TIME + $SLEEP_TIME" | bc`
                eval $CMD_SSH > /dev/null
                rc=$?
                if [ $TIME -gt $RETRY_TIME ]
                then
                        log_info "$i does not boot in $RETRY_TIME. Aborting." $ERROR_LOG_CODE
                        exit 1
                fi

        done
	log_info "$i booted after $TIME seconds." $OK_LOG_CODE
done

# INSTALLING TSAM SOFTWARE
for node in `echo $TSAM_NODES | tr ',' ' '`
do
	install_tsam $node $TSAM_FILE $TSAM_LICENSE_FILE
done

####################
# CONFIGURING TSAM #
####################

# CREATING AND ACTIVATING PEER DOMAIN
tsam_setup

sleep $DELAY

# TIE BREAKER
tsam_tiebreaker

# DETECT NETWORK CONNECTIVITY LOST WITHOUT NETWORK LINK LOST
l3_network_issue

# HB DISK
tsam_hb_disk

# FINISHING
log_info "Installation finished successfully. :-O" $OK_LOG_CODE

exit 0
