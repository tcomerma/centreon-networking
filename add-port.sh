#!/bin/sh
# FILE: "add-port"
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

CLAPI='/usr....core/centreon.pl'

log() {
  if [ $VERBOSE -eq 1 ]
    then
      echo $1
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
  echo "   -n Name off the host. Goes to HOSTNAME"
  echo "   -G Hostgroup where the host will belong"
  echo "   -T Host Template to apply"
  echo "   -r Restart poller to apply configuration. Default=No"
  echo "  "
  echo "   Default values for optional parameters [] are picked from default.settings file from same directory"
	echo ""
  exit $STATE_UNKNOWN
}

# Load file with default values
. $PROGPATH/default.settings

STATE_OK=0
STATE_ERROR=1


# Proces de parametres
while getopts "H:n:d:T:rhV" Option
do
	case $Option in
    H ) HOST=$OPTARG;;
    n ) NAME=$OPTARG;;
    d ) DESCRIPTION=$OPTARG;;
    T ) SERVICE_TEMPLATE=$OPTARG;;
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
log "  HOST_TEMPLATE: $HOST_TEMPLATE"
log "  Restart after: $RESTART"

# Check parameters
if [ -z "$HOST" ] ; then
	echo " Error - NO HOSTADDRESS provided "
	echo ""
	print_help
	echo ""
fi

if [ -z "$NAME" ] ; then
  echo " Error - Missing NAME "
  echo ""
  print_help
  echo ""
fi

#Consulta a 1.0.8802.1.1.2.1.3.7.1.3 cercant el nom d'interface que s'ha indicat com a paràmetre
#iso.0.8802.1.1.2.1.3.7.1.3.67 = STRING: "ge.1.3"
#Obtenir el darrer número del OID
#Consulta a 1.0.8802.1.1.2.1.4.1.1.7.0.262.ID per obtenir el nom de port
#iso.0.8802.1.1.2.1.4.1.1.7.0.262.9 = STRING: "ge.1.46"
#Consulta a 1.0.8802.1.1.2.1.4.1.1.9.0.262.ID per obtenir el nom de switch
#iso.0.8802.1.1.2.1.4.1.1.9.0.262.9 = STRING: "C3-ESTCEIDADES-CC4-N1"

if [ -z "$DESCRIPTION" ] ; then
  # Try to find interface details using snmp and lldp
  int_id=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $HOST 1.0.8802.1.1.2.1.3.7.1.3 | grep "\"$NAME\"" | cut -f 12 -d . | cut -f 1 -d "="`
  if [ $? -eq 0 ]
    then
      # Continue to find remote port
      remote_port=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOST 1.0.8802.1.1.2.1.4.1.1.7.0.$int_id`
      if [ $? -eq 0 ]
        then
          remote_system=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOST 1.0.8802.1.1.2.1.4.1.1.9.0.$int_id`
            if [ $? -eq 0 || -z "$remote_system" ]
              then
                DESCRIPTION=`echo "$NAME -> $remote_system: $remote_port" | tr -d '"'`
              else
                # Try to find system hardware id instead of name
                remote_system=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOST 1.0.8802.1.1.2.1.4.1.1.5.0.$int_id | tr " " "-"`
                if [ $? -eq 0 ]
                  then
                    DESCRIPTION=`echo "$NAME -> $remote_system: $remote_port" | tr -d '"'`
                  else
                    DESCRIPTION=`echo "$NAME -> ????: $remote_port" | tr -d '"'`
                  fi
              fi
        else
          DESCRIPTION="$NAME"
        fi
    else
      echo "WARNING: SNMP query failed"
      DESCRIPTION="$NAME"
    fi  
  log "DESCRIPTION (from SNMP): $DESCRIPTION"
fi

# Check if service already exists
H=`perl $CLAPI -u $USER -p $PASSWORD -o HOST -a show -v $HOST | grep $HOST`
if [ "$H" ]
  then
    echo "ERROR: Host $HOST already exists"
    exit $STATE_ERROR
  fi


# Create service
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a add -v "$NAME;$NAME;$HOST;$HOST_TEMPLATE;$POLLER;$HOSTGROUP"
if []
  then

  fi
# Configure service
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a setparam -v "$NAME;snmp_community;SNMP_COMMUNITY"
if []
  then

  fi
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a setparam -v "$NAME;snmp_version;SNMP_VERSION"
if []
  then

  fi
# If RESTART to apply config is asked, do it.
perl $CLAPI -u $USER -p $PASSWORD -o HOST -a APPLYCFG -v "$POLLER"
if []
  then

  fi

exit $STATE_OK
