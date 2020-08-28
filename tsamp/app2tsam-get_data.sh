#!/bin/bash

# (c) 2012 Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
#     Distributed under GNU GPL v2 License                    
#     See COPYING.txt for more details                        

SCRIPT_VERSION="0.99999 BETA"
MAINTITLE="(c) LVTC 2012 Version $SCRIPT_VERSION - Application clustering - "
MAINSUBTITLE=""
SCRIPT_NAME=$0
CREATE_CLUSTER_SCRIPT_NAME="app2tsam-install-tsam.sh"
CREATE_CLUSTER_RESOURCES_SCRIPT_NAME="app2tsam-config-rsrc-tsam.sh"

#
# INFO FILES
#

INFO_BANNER_FILE=banner.txt
LICENSE_FILE=license.txt

#
# CONFIGURATION FILES
#

CONFDIR=/tmp
TSAM_TGZ_FILE=$CONFDIR/tsam-tgz-file.tmp
APP_START_FILE=$CONFDIR/app-start-cmd.tmp
APP_STOP_FILE=$CONFDIR/app-stop-cmd.tmp
APP_MONITOR_FILE=$CONFDIR/app-monitor-cmd.tmp
APP_VIP_FILE=$CONFDIR/app-vip.tmp
APP_VGS_FILE=$CONFDIR/app-vgs.tmp
TSAM_LICENSE_FILE=$CONFDIR/tsam-license.tmp
TSAM_NODES_FILE=$CONFDIR/tsam-nodes.tmp
TSAM_PEERDOMAIN_FILE=$CONFDIR/tsam-peerdomain.tmp
TSAM_MAIN_RGROUP_FILE=$CONFDIR/tsam-main-rgroup.tmp
TSAM_HB_DISK_FILE=$CONFDIR/tsam-hbdisk.tmp
TSAM_HB_SIZE_FILE=$CONFDIR/tsam-hbdisk-size.tmp
TSAM_TIEBREAKER_FILE=$CONFDIR/tsam-tiebreaker.tmp
TSAM_MONITOR_PERIOD_FILE=$CONFDIR/tsam-monitorperiod.tmp
TSAM_MONITOR_TIMEOUT_FILE=$CONFDIR/tsam-monitortimeout.tmp
TSAM_START_TIMEOUT_FILE=$CONFDIR/tsam-starttimeout.tmp
TSAM_STOP_TIMEOUT_FILE=$CONFDIR/tsam-stoptimeout.tmp
CONF_FILE=$CONFDIR/global-configuration-file.tmp
GLOBAL_CONF_FILE=""

#
# COMMANDS
#

create_global_conf () {
	GLOBAL_CONF_FILE=$CONFDIR"/"`cat $CONF_FILE`
	# TSAM TGZ
	STRING="TSAM_BIN="
        STRING=$STRING`cat $TSAM_TGZ_FILE`
        echo $STRING > $GLOBAL_CONF_FILE
        # TSAM LICENSE
        STRING="TSAM_LICENSE="
        STRING=$STRING`cat $TSAM_LICENSE_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
	# TSAM NODES
	STRING="TSAM_NODES="
	STRING=$STRING`cat $TSAM_NODES_FILE`
	echo $STRING >> $GLOBAL_CONF_FILE
	# PEER DOMAIN
	STRING="TSAM_PEERDOMAIN="
        STRING=$STRING`cat $TSAM_PEERDOMAIN_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
	# MAIN RGROUP
        STRING="TSAM_MAIN_RGROUP="
        STRING=$STRING`cat $TSAM_MAIN_RGROUP_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # HEARTBEAT DISK
        STRING="TSAM_HB_DISK="
        STRING=$STRING`cat $TSAM_HB_DISK_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # HEARTBEAT DISK SIZE
        STRING="TSAM_HB_SIZE="
        STRING=$STRING`cat $TSAM_HB_SIZE_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # TIEBREAKER
        STRING="TSAM_TIEBREAKER="
        STRING=$STRING`cat $TSAM_TIEBREAKER_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # MONITOR PERIOD
        STRING="TSAM_MONITOR_PERIOD="
        STRING=$STRING`cat $TSAM_MONITOR_PERIOD_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # MONITOR TIMEOUT
        STRING="TSAM_MONITOR_TIMEOUT="
        STRING=$STRING`cat $TSAM_MONITOR_TIMEOUT_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # START TIMEOUT
        STRING="TSAM_START_TIMEOUT="
        STRING=$STRING`cat $TSAM_START_TIMEOUT_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # STOP TIMEOUT
        STRING="TSAM_STOP_TIMEOUT="
        STRING=$STRING`cat $TSAM_STOP_TIMEOUT_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # START COMMAND
        STRING="APP_START_CMD="
        STRING=$STRING`cat $APP_START_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # STOP COMMAND
        STRING="APP_STOP_CMD="
        STRING=$STRING`cat $APP_STOP_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # MONITOR COMMAND
        STRING="APP_MONITOR_CMD="
        STRING=$STRING`cat $APP_MONITOR_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # VIP
        STRING="APP_VIP="
        STRING=$STRING`cat $APP_VIP_FILE`
        echo $STRING >> $GLOBAL_CONF_FILE
        # VGS
        STRING="APP_VGS="
        STRING=$STRING`cat $APP_VGS_FILE | tr '\n' ',' | sed -e 's/,$//g'`
        echo $STRING >> $GLOBAL_CONF_FILE
}

#
# FUNCTION TO GET GLOBAL CONFIGURATION FILE
#

get_global_conf_file_name () {
	dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "Global configuration file" \
               --inputbox "Provide the file name (without path) to store TSAM configuration:" 8 60 2>$CONF_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO GET DEVICE SIZE
#

get_device_size () {
	DEVICEBYTES=`cat /proc/partitions | grep $1 | awk -F' ' '{print $3}'`
	SIZES=(KB MB GB TB)
	i=1
	while true
	do
        	DEVICESIZE=`echo "$DEVICEBYTES / 1024" | bc`
	        if [ $DEVICESIZE -lt 1024 ]
	        then
        	        break
	        fi
	        let ++i
        	DEVICEBYTES=$DEVICESIZE
	done

	echo $DEVICESIZE${SIZES[$i]}
}

#
# CHECK IF DEVICE IS A INITIALIZED LVM PV
#

check_device_lvm () {

	DUMMYCMD=`pvscan | grep $1`
	if [ -z "$DUMMYCMD" ]
	then 
		return 1
	fi
	return 0 # RETURNS 0 IF ARGUMENT IS A INITIALIZED LVM PV

}

#
# FUNCION QUE PIDE EL COMAND PARA ARRANCAR SERVICIO
#

get_app_start_cmd () {
	dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
	       --title "Application start" \
	       --inputbox "Provide a command to start application:" 8 60 2>$APP_START_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR A COMMAND TO STOP APPLICATION
#

get_app_stop_cmd () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
	       --title "Application stop" \
	       --inputbox "Provide a command to stop application:" 8 60 2>$APP_STOP_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR A COMMAND TO MONITOR APPLICATION
#

get_app_monitor_cmd () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
	       --title "Application monitoring" \
	       --inputbox "Provide a command to check application status:" 8 60 2>$APP_MONITOR_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR VIP
#

get_app_vip () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
	       --title "Application VIP" \
	       --inputbox "Provide VIP:" 8 60 2>$APP_VIP_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR VGs
#

get_app_vgs () {
	VGS=`vgs | sed 1d | awk -F' ' '{print $1}'`
	OPTVGS=""
	for vg in $VGS
	do
		OPTVGS=(${OPTVGS[@]} $vg /dev/$vg off)
	done
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
	       --title "Application data Volume Groups" \
	       --separate-output --checklist "Select application data VGs:" 22 76 10 ${OPTVGS[@]} 2>$APP_VGS_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR TSAM TGZ FILE
#

get_tsam_tgz () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "TSAM tgz file" \
               --inputbox "Provide local path to TSAM tgz file:" 8 60 2>$TSAM_TGZ_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR TSAM LICENSE FILE
#

get_tsam_license () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "TSAM License" \
               --inputbox "Provide local path to TSAM license file:" 8 60 2>$TSAM_LICENSE_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR CLUSTER NODES
#

get_tsam_nodes () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "Cluster nodes" \
               --inputbox "Provide nodes FQDN (comma separated):" 8 60 2>$TSAM_NODES_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR PEER DOMAIN NAME
#

get_tsam_peerdomain () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "Peer domain name" \
               --inputbox "Provide peer domain name:" 8 60 2>$TSAM_PEERDOMAIN_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR MAIN RESOURCE GROUP NAME
#

get_tsam_rgroup_name () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "Main resource group name" \
               --inputbox "Provide main resource group name:" 8 60 2>$TSAM_MAIN_RGROUP_FILE
        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR HEARTBEAT DISK
#

get_tsam_hbdisk () {
	FREEDEVICES=`lvmdiskscan | grep "/dev/sd" | awk -F' ' '{print $1}' | sed -e '/[[:digit:]]$/d'`
	OPTHBDISK=""
	DEFAULT=on
	for disk in $FREEDEVICES
	do
		# CHECK IF disk IS INITIALIZED AS LVM PV
		check_device_lvm $disk
		rc=$?
		if [ $rc -eq 0 ]
		then
			continue
		fi
		DEVICE=`echo $disk | sed -e 's/\/dev\///g'`
		SIZE=$(get_device_size $DEVICE)
		OPTHBDISK=(${OPTHBDISK[@]} " $disk $SIZE $DEFAULT")
		DEFAULT=off
	done

        if [ -z $OPTHBDISK ]
        then
                TEXT="There is no available disk to be chosen as heartbeat disk. Please free disks or add new ones."
                dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
                        --title "Disk heartbeating configuration" \
                        --msgbox "$TEXT" 22 70
                exit 1
        fi

	dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
	       --title "Disk heartbeating configuration" \
	       --radiolist "Choose the device to setup disk heartbeating:" 10 60 4 ${OPTHBDISK[@]} 2>$TSAM_HB_DISK_FILE

        rc=$?
        if [ $rc -eq 1 ]
        then
                exit 1
        fi
}

#
# FUNCTION TO ASK FOR TIEBREAKER
#

get_tsam_tiebreaker () {
	TXT="Manual tiebreaking is configured by default.\n\nDo you want to configure network tiebreaker?"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM tiebreaker mechanism"  --yesno "$TXT" 8 60
	rc=$?
	if [ $rc -eq 0 ]
	then
		get_tsam_network_tiebreaker
	else
		echo "Operator" > $TSAM_TIEBREAKER_FILE
	fi
}

#
# FUNCTION TO ASK FOR A TSAM ATTRIBUTE VALUE
#

# $1 File where to store it
# $2 Descriptive text
# $3 --title text

get_tsam_attribute_value () {
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "\"$3\"" \
               --inputbox "$2" 8 90 2>"$1"
}

#
# FUNCTION TO ASK FOR NETWORK TIEBREAKER IP
#

get_tsam_network_tiebreaker () {
	dialog --backtitle "$MAINTITLE$MAINSUBTITLE" \
               --title "Network tiebreaker" \
               --inputbox "Provide a network tiebreaker ip address:" 8 60 2>$TSAM_TIEBREAKER_FILE
}

###########
# BANNERS #
###########

MAINSUBTITLE="Script information and disclaimer"

dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Script information" --textbox $INFO_BANNER_FILE 22 105

MAINSUBTITLE="License agreetment and distribution"

TXT=`cat $LICENSE_FILE`

dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "License agreetment"  --yesno "$TXT" 16 60
rc=$?
# FINISH
if [ $rc -eq 1 ]
then
	exit 1
fi

##########
# GLOBAL #
##########

MAINSUBTITLE="Global"

if [ -s $CONF_FILE ]
then
        GLOBAL_FILE=`cat $CONF_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following file to store TSAM cluster configuration:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Application start command"  --yesno "$TXT$GLOBAL_FILE" 10 60
        rc=$?
        # IF COMMAND IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $CONF_FILE
                get_global_conf_file_name
        fi
else
	get_global_conf_file_name
fi

###############
# APPLICATION #
###############

MAINSUBTITLE="Application data"

#
# ASK FOR COMMAND TO START APPLICATION
#

if [ -s $APP_START_FILE ]
then
	START_CMD=`cat $APP_START_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following command to start the application:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Application start command"  --yesno "$TXT$START_CMD" 10 60
        rc=$?
        # IF COMMAND IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $APP_START_FILE
                get_app_start_cmd
        fi
else
        get_app_start_cmd
fi

#
# ASK FOR COMMAND TO STOP APPLICATION
#

if [ -s $APP_STOP_FILE ]
then
	STOPCMD=`cat $APP_STOP_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following command to stop the application:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Application stop command"  --yesno "$TXT$STOPCMD" 10 60
        rc=$?
        # IF COMMAND IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $APP_STOP_FILE
                get_app_stop_cmd
        fi
else
        get_app_stop_cmd
fi

#
# ASK FOR COMMAND TO MONITOR APPLICATION
#

if [ -s $APP_MONITOR_FILE ]
then
	MONITORCMD=`cat $APP_MONITOR_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following command to monitor the application:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Application monitor command"  --yesno "$TXT$MONITORCMD" 10 60
        rc=$?
        # IF COMMAND IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $APPMMONITORFILE
                get_app_monitor_cmd
        fi
else
        get_app_monitor_cmd
fi

#
# ASKING FOR VIP
#

if [ -s $APP_VIP_FILE ]
then
        VIPDATA=`cat $APP_VIP_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following VIP:\n\nVIP: "
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Application VIP"  --yesno "$TXT$VIPDATA" 10 60
        rc=$?
        # IF VIP IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $APP_VIP_FILE
                get_app_vip
        fi
else
        get_app_vip
fi

#
# ASKING FOR VGs
#

if [ -s $APP_VGS_FILE ]
then
        VGSDATA=`cat $APP_VGS_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following VGs:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Application VGs"  --yesno "$TXT$VGSDATA" 10 60
        rc=$?
        # IF VGS ARE WRONG ASK FOR THEM
        if [ $rc -eq 0 ]
        then
                rm -f $APP_VGS_FILE
                get_app_vgs
        fi
else
        get_app_vgs
fi


########
# TSAM #
########

MAINSUBTITLE="TSAM data"

#
# ASK FOR TSAM TGZ
#

if [ -s $TSAM_TGZ_FILE ] 
then
        TSAM_TGZ=`cat $TSAM_TGZ_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following path to TSAM tgz file:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM tgz file"  --yesno "$TXT$TSAM_TGZ" 10 60
        rc=$?
        # IF LICENSE FILE IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_TGZ_FILE
                get_tsam_tgz
        fi
else
	get_tsam_tgz
fi

#
# ASK FOR TSAM LICENSE FILE
#

if [ -s $TSAM_LICENSE_FILE ]
then
        TSAM_LICENSE=`cat $TSAM_LICENSE_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following path to TSAM license file:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM license file"  --yesno "$TXT$TSAM_LICENSE" 10 60
        rc=$?
        # IF LICENSE FILE IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_LICENSE_FILE
                get_tsam_license
        fi
else
        get_tsam_license
fi

#
# ASK FOR CLUSTER NODES
#

if [ -s $TSAM_NODES_FILE ]
then
        TSAM_NODES=`cat $TSAM_NODES_FILE | tr "," "\n"`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following cluster nodes:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM cluster nodes"  --yesno "$TXT$TSAM_NODES" 10 60
        rc=$?
        # IF CLUSTER NODES ARE WRONG ASK FOR THEM
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_NODES_FILE
                get_tsam_nodes
        fi
else
        get_tsam_nodes
fi

#
# ASK FOR PEER DOMAIN
#

if [ -s $TSAM_PEERDOMAIN_FILE ]
then
	TSAM_PEER_DOMAIN=`cat $TSAM_PEERDOMAIN_FILE`"\n\nDo you want to change it?"
	TXT="A configuration file has been found including the following peer domain name:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM peer domain"  --yesno "$TXT$TSAM_PEER_DOMAIN" 10 60
        rc=$?
        # IF PEER DOMAIN IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_PEERDOMAIN_FILE
                get_tsam_peerdomain
        fi
else
	get_tsam_peerdomain
fi

#
# ASK FOR MAIN RESOURCE GROUP NAME
#

if [ -s $TSAM_MAIN_RGROUP_FILE ]
then
        TSAM_MAIN_RGROUP=`cat $TSAM_MAIN_RGROUP_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following main resource group name:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM main resource group name"  --yesno "$TXT$TSAM_MAIN_RGROUP" 10 60
        rc=$?
        # IF PEER DOMAIN IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_MAIN_RGROUP_FILE
                get_tsam_rgroup_name
        fi
else
        get_tsam_rgroup_name
fi

#
# ASKING FOR TIEBREKAER
#

if [ -s $TSAM_TIEBREAKER_FILE ]
then
        TSAM_TIEBREAKER=`cat $TSAM_TIEBREAKER_FILE`
	if [ $TSAM_TIEBREAKER = "Operator" ]
	then
		TXT="Manual tiebreaking is configured.\n\nDo you want to change it?"
	        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM tiebreaker"  --yesno "$TXT" 10 60
		rc=$?
	        if [ $rc -eq 0 ]
        	then
        		get_tsam_network_tiebreaker 
	        fi
	else
		TXT="Network tiebreaking is configured to $TSAM_TIEBREAKER.\n\nDo you want to change it?"
                dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "TSAM tiebreaker"  --yesno "$TXT" 10 60
                rc=$?
	        if [ $rc -eq 0 ]
        	then
                	get_tsam_tiebreaker
	        fi
	fi
else
        get_tsam_tiebreaker
fi

#
# ASKING FOR HEARTBEAT DISK
#

if [ -s $TSAM_HB_DISK_FILE ]
then
        TSAM_HB_DISK=`cat $TSAM_HB_DISK_FILE`"\n\nDo you want to change it?"
        TXT="A configuration file has been found including the following device for disk heartbeating:\n\n"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Disk heartbeating"  --yesno "$TXT$TSAM_HB_DISK" 10 60
        rc=$?
        # IF HB DISK IS WRONG ASK FOR IT
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_HB_DISK_FILE
		get_tsam_hbdisk
        fi
else
        get_tsam_hbdisk
fi

#
# ASKING FOR HEARTBEAT DISK LOGICAL VOLUME SIZE
#

TSAM_HBDISKSIZE_TITLE="Size of logical volume use for disk heartbeating (MB)"
TSAM_HBDISKSIZE_TXT="Provide the size of the logical volume you want to use for disk heartbeating (MB):"

if [ -s $TSAM_HB_SIZE_FILE ]
then
        TSAM_HB_DISK_SIZE=`cat $TSAM_HB_SIZE_FILE`
        TXT="Logical volume size for heartbeat disk is $TSAM_HB_DISK_SIZE (MB).\n\nDo you want to change it?"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "$TSAM_HBDISKSIZE_TITLE"  --yesno "$TXT" 10 90
        rc=$?
        # CHANGE VALUE
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_HB_SIZE_FILE
                get_tsam_attribute_value $TSAM_HB_SIZE_FILE "$TSAM_HBDISKSIZE_TXT" "$TSAM_HBDISKSIZE_TITLE"
        fi
else
        get_tsam_attribute_value $TSAM_HB_SIZE_FILE "$TSAM_HBDISKSIZE_TXT" "$TSAM_HBDISKSIZE_TITLE"
fi

#
# ASK FOR MONITOR PERIOD
#

TSAM_IBMAPPLICATION_TITLE="Monitor Command Period (IBM.Application MonitorCommandPeriod)"
TSAM_IBMAPPLICATION_TXT="Provide the interval (seconds) between application checkings:"

if [ -s $TSAM_MONITOR_PERIOD_FILE ]
then
	TSAM_MONITOR_PERIOD=`cat $TSAM_MONITOR_PERIOD_FILE`
	TXT="Every $TSAM_MONITOR_PERIOD seconds TSAM will check for application status.\n\nDo you want to change it?"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "$TSAM_IBMAPPLICATION_TITLE"  --yesno "$TXT" 10 90
	rc=$?
        # CHANGE VALUE
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_MONITOR_PERIOD_FILE
                get_tsam_attribute_value $TSAM_MONITOR_PERIOD_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
        fi
else
	get_tsam_attribute_value $TSAM_MONITOR_PERIOD_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
fi

#
# ASK FOR MONITOR TIMEOUT
#

TSAM_IBMAPPLICATION_TITLE="Monitor Command TimeOut (IBM.Application MonitorCommandTimeOut)"
TSAM_IBMAPPLICATION_TXT="Provide the number of seconds after TSAM will consider the application has failed if monitor command has not returned any value:"

if [ -s $TSAM_MONITOR_TIMEOUT_FILE ]
then
        TSAM_MONITOR_TIMEOUT=`cat $TSAM_MONITOR_TIMEOUT_FILE`
        TXT="If monitor status has not returned any status code after $TSAM_MONITOR_TIMEOUT seconds TSAM will consider the application monitor command failed to check application status.\n\nDo you want to change it?"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "$TSAM_IBMAPPLICATION_TITLE"  --yesno "$TXT" 10 90
        rc=$?
        # CHANGE THE VALUE
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_MONITOR_TIMEOUT_FILE
                get_tsam_attribute_value $TSAM_MONITOR_TIMEOUT_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
        fi
else
        get_tsam_attribute_value $TSAM_MONITOR_TIMEOUT_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
fi

#
# ASK FOR START COMMAND TIMEOUT
#

TSAM_IBMAPPLICATION_TITLE="Start Command TimeOut (IBM.Application StartCommandTimeOut)"
TSAM_IBMAPPLICATION_TXT="Provide the number of seconds after TSAM will consider the application start command failed to bring the application online if start command has not returned any value:"

if [ -s $TSAM_START_TIMEOUT_FILE ]
then
        TSAM_START_TIMEOUT=`cat $TSAM_START_TIMEOUT_FILE`
        TXT="If start command has not returned any status code after $TSAM_START_TIMEOUT seconds TSAM will consider the start command application failed to bring the application online.\n\nDo you want to change it?"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "$TSAM_IBMAPPLICATION_TITLE"  --yesno "$TXT" 10 90
        rc=$?
        # CHANGE DE VALUE
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_START_TIMEOUT_FILE
                get_tsam_attribute_value $TSAM_START_TIMEOUT_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
        fi
else
        get_tsam_attribute_value $TSAM_START_TIMEOUT_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
fi

#
# ASK FOR STOP COMMAND TIMEOUT
#

TSAM_IBMAPPLICATION_TITLE="Stop Command TimeOut (IBM.Application StopCommandTimeOut)"
TSAM_IBMAPPLICATION_TXT="Provide the number of seconds after TSAM will consider the application stop command failed to bring the application offline if stop command has not returned any value:"


if [ -s $TSAM_STOP_TIMEOUT_FILE ]
then
        TSAM_STOP_TIMEOUT=`cat $TSAM_STOP_TIMEOUT_FILE`
        TXT="If stop command has not returned any status code after $TSAM_STOP_TIMEOUT seconds TSAM will consider the stop command application failed to bring the application offline.\n\nDo you want to change it?"
        dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "$TSAM_IBMAPPLICATION_TITLE"  --yesno "$TXT" 12 90
        rc=$?
        # CHANGE THE VALUE
        if [ $rc -eq 0 ]
        then
                rm -f $TSAM_STOP_TIMEOUT_FILE
                get_tsam_attribute_value $TSAM_STOP_TIMEOUT_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
        fi
else
        get_tsam_attribute_value $TSAM_STOP_TIMEOUT_FILE "$TSAM_IBMAPPLICATION_TXT" "$TSAM_IBMAPPLICATION_TITLE"
fi

###########################
# CREATE GLOBAL CONF FILE #
###########################

create_global_conf

MAINSUBTITLE="Configuration summary"
TXT="$SCRIPT_NAME has created a config file including all the configuration you provided in $GLOBAL_CONF_FILE.\n\nNow if you want to cluster the application which you have just supplied the information for you need to run $CREATE_CLUSTER_SCRIPT_NAME using as argument the configuration file $GLOBAL_CONF_FILE to install TSAM.\n\nAfter that to create the resource groups yo need to run $CREATE_CLUSTER_RESOURCES_SCRIPT_NAME using as argument the configuration file $GLOBAL_CONF_FILE.\n\nHave fun!!!"

dialog --backtitle "$MAINTITLE$MAINSUBTITLE" --title "Information" --msgbox "$TXT" 22 105
