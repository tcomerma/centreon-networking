#!/bin/sh
# FILE: "add-switch"
# DESCRIPTION: 
# AUTHOR: Toni Comerma
# DATE: jun-2016
#
# Notes:
#   


PROGNAME=`basename $0`
PROGPATH=`dirname $0`
REVISION='Version: 0.1'

VERBOSE=1

CLAPI='/usr/local/centreon/www/modules/centreon-clapi/core/centreon'

log() {
  if [ $VERBOSE -eq 1 ]
    then
      echo "$1"
    fi

}
print_help() {
  echo "Usage:"
  echo "  $PROGNAME  [-u USERNAME] [-p PASSWORD] -H HOSTADDRESS -n HOSTNAME -G HOSTGROUP [-T TEMPLATE] [-r]"
  echo "  $PROGNAME -h "
	echo "  $REVISION"
	echo "  "
  echo "   Adds a host to the centreon database"
  echo "   -u Centreon username with admin privileges"
  echo "   -p Password for this username"
  echo "   -H IP o DNS name for the host. Goes to HOSTADDRESS field"
  echo "   -n Name of the host. Goes to HOSTNAME"
  echo "   -G Hostgroup where the host will belong"
  echo "   -T Host Template to apply"
  echo "   -r Restart poller to apply configuration. Default=No"
  echo "  "
  echo "   Default values for optional parameters [] are picked from default.settings file from same directory"
	echo ""
  exit $STATE_ERROR
}

# Load file with default values
. $PROGPATH/default.settings

STATE_OK=0
STATE_ERROR=1


# Proces de parametres
while getopts "u:p:H:n:G:d:T:rhV" Option
do
	case $Option in
		u ) USER=$OPTARG;;
		p ) PASSWORD=$OPTARG;;
    H ) HOST=$OPTARG;;
    G ) HOSTGROUP=$OPTARG;;
    n ) NAME=$OPTARG;;
    d ) DESCRIPTION=$OPTARG;;
    T ) HOST_TEMPLATE=$OPTARG;;
    r ) RESTART=yes;;
    V ) VERBOSE=1;;
		h ) print_help;;
		* ) echo "unimplemented option";;
		esac
done

log "Parametres:"
log "  USER: $USER"
log "  PASSWORD: $PASSWORD"
log "  NAME: $NAME"
log "  HOSTNAME: $HOST"
log "  HOSTGROUP: $HOSTGROUP"
log "  DESCRIPTION: $DESCRIPTION"
log "  HOST_TEMPLATE: $HOST_TEMPLATE"
log "  Restart after: $RESTART"

# Check parameters
if [ -z "$HOST" ] ; then
	echo " Error - NO HOSTADDRESS provided "
	echo ""
	print_help
	echo ""
fi

if [ -z "$HOSTGROUP" ] ; then
  echo " Error - Missing HOSTGROUP "
  echo ""
  print_help
  echo ""
fi

if [ -z "$NAME" ] ; then
  # Try to find name using snmp
  name=`snmpget -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOST system.sysName.0`
  if [ $? -eq 0 ]
    then
      NAME="$name"
      log "  NAME (from SNMP): $NAME"
    else
      echo "WARNING: SNMP query failed"
    fi   
fi

if [ -z "$DESCRIPTION" ] ; then
  # Try to find name using snmp
  description=`snmpget -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOST system.sysDescr.0`
  if [ $? -eq 0 ]
    then
      DESCRIPTION="$description"
      log "  DESCRIPTION (from SNMP): $DESCRIPTION"
    else
      echo "WARNING: SNMP query failed"
    fi   
fi

# Check if host already exists
H=`perl $CLAPI -u $USER -p $PASSWORD -o HOST -a show -v $HOST | grep $HOST`
if [ "$H" ]
  then
    echo "ERROR: Host $HOST already exists"
    exit $STATE_ERROR
  fi


# Create host
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a add -v "$NAME;$DESCRIPTION;$HOST;$HOST_TEMPLATE;$POLLER;$HOSTGROUP"
if [ $? -ne 0 ]
  then
    echo "ERROR: Unable to create $HOST"
    exit $STATE_ERROR
  fi
# Configures host
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a setparam -v "$NAME;snmp_community;SNMP_COMMUNITY"
if [ $? -ne 0 ]
  then
    echo "ERROR: Unable to set SNMP community"
    exit $STATE_ERROR
  fi
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a setparam -v "$NAME;snmp_version;SNMP_VERSION"
if [ $? -ne 0 ]
  then
    echo "ERROR: Unable set SNMP version"
    exit $STATE_ERROR
  fi
# If RESTART to apply config is asked, do it.
if [ "RESTART" == "yes" ]
  then
    perl $CLAPI -u $USER -p $PASSWORD -a APPLYCFG -v "$POLLER"
    if [ $? -ne 0 ]
      then
        echo "ERROR: Problem restarting poller"
        exit $STATE_ERROR
      fi
  fi
exit $STATE_OK
