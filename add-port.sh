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
  echo "   -n Name off the host. Goes to HOSTNAME"
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
while getopts "n:p:d:T:rhV" Option
do
	case $Option in
    H ) HOST=$OPTARG;;
    n ) HOSTNAME=$OPTARG;;
    p ) PORT=$OPTARG;;
    d ) DESCRIPTION=$OPTARG;;
    T ) SERVICE_TEMPLATE=$OPTARG;;
    r ) RESTART=yes;;
    V ) VERBOSE=1;;
		h ) print_help;;
		* ) echo "unimplemented option"
        print_help
		esac
done

log "Parametres:"
log "  USER: $USER"
log "  PASSWORD: $PASSWORD"
log "  PORT: $PORT"
log "  HOSTNAME: $HOSTNAME"
log "  HOSTGROUP: $HOSTGROUP"
log "  HOST_TEMPLATE: $HOST_TEMPLATE"
log "  Restart after: $RESTART"

# Check parameters
if [ -z "$HOSTNAME" ] ; then
  echo " Error - Missing HOSTNAME"
  echo ""
  print_help
  echo ""
fi


# Try to get HOSTADDRESS from centreon
HOSTADDRESS=`perl $CLAPI -u $USER -p $PASSWORD -o HOST -a show -v "$HOSTNAME"  | tail -n +2 |cut -f 4 -d ";"`
if [ $? -ne 0 ]
  then
    echo "ERROR: Unable to find $HOSTNAME"
    exit $STATE_ERROR
  fi
log "  HOSTADDRESS: $HOSTADDRESS"

#Consulta a 1.0.8802.1.1.2.1.3.7.1.3 cercant el nom d'interface que s'ha indicat com a paràmetre
#iso.0.8802.1.1.2.1.3.7.1.3.67 = STRING: "ge.1.3"
#Obtenir el darrer número del OID
#Consulta a 1.0.8802.1.1.2.1.4.1.1.7.0.262.ID per obtenir el nom de port
#iso.0.8802.1.1.2.1.4.1.1.7.0.262.9 = STRING: "ge.1.46"
#Consulta a 1.0.8802.1.1.2.1.4.1.1.9.0.262.ID per obtenir el nom de switch
#iso.0.8802.1.1.2.1.4.1.1.9.0.262.9 = STRING: "C3-ESTCEIDADES-CC4-N1"

# Check if service already exists
S=`perl $CLAPI -u $USER -p $PASSWORD -o SERVICE -a show -v $PORT | cut -f 4 -d ";" | cut -c 1-6 | grep $PORT`
if [ "$S" ]
  then
    echo "ERROR: Service $S for host $HOSTNAME already exists"
    exit $STATE_ERROR
  fi


# Try to fill description from SNMP and LLDP
if [ -z "$DESCRIPTION" ] ; then
  # Try to find interface details using snmp and lldp
  int_id=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION $HOSTADDRESS 1.0.8802.1.1.2.1.3.7.1.3 | grep "\"$PORT\"" | cut -f 12 -d . | cut -f 1 -d "="`
  if [[ $? -eq 0 && $int_id != *"OID"* ]]
    then
      int_id=`echo "$int_id" | tr -d " "` 
      # Continue to find remote port
      remote_port=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOSTADDRESS 1.0.8802.1.1.2.1.4.1.1.7.0.$int_id`
      if [[ $? -eq 0 && $remote_port != *"OID"* ]]
        then
          remote_system=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOSTADDRESS 1.0.8802.1.1.2.1.4.1.1.9.0.$int_id`
            if [[ $? -eq 0 && $remote_port != *"OID"* ]]
              then
                DESCRIPTION=`echo "$PORT --- $remote_system: $remote_port" | tr -d '"'`
              else
                # Try to find system hardware id instead of name
                remote_system=`snmpwalk -c $SNMP_COMMUNITY -v $SNMP_VERSION -Ov -Oq $HOSTADDRESS 1.0.8802.1.1.2.1.4.1.1.5.0.$int_id | tr " " "-"`
                if [[ $? -eq 0 && $remote_system != *"OID"* ]]
                  then
                    DESCRIPTION=`echo "$PORT --- $remote_system: $remote_port" | tr -d '"'`
                  else
                    DESCRIPTION=`echo "$PORT --- ????: $remote_port" | tr -d '"'`
                  fi
              fi
        else
          DESCRIPTION="$PORT"
        fi
    else
      DESCRIPTION="$PORT"
    fi  
  log "DESCRIPTION (from SNMP): $DESCRIPTION"
else
  DESCRIPTION="$PORT: $DESCRIPTION"
fi



# Create service
perl $CLAPI -u $USER -p $PASSWORD -o SERVICE -a add -v "$HOSTNAME;$DESCRIPTION;$SERVICE_TEMPLATE_TRAFFIC"
if [ $? -eq 0 ]
  then
   echo "."
  fi

# Configure service
perl $CLAPI -u $USER -p $PASSWORD -o SERVICE -a SETMACRO -v "$HOSTNAME;$DESCRIPTION;INTERFACE;$PORT"
if [ $? -eq 0 ]
  then
    echo "."

  fi
  exit
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
