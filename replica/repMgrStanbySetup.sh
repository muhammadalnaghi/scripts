#!/bin/sh

#################################################
#  RepMgr Standby setup script                  #
#  Author: Karsten Lenz dbi-services 2022.08.11 #
#################################################

progName=$(basename $0)
# postgresVersion=14
domain=localdomain
# repmgr_conf=/etc/repmgr/$postgresVersion/repmgr.conf
# pgData=/pgdata/$postgresVersion/data
# postgresConf=/pgdata/$postgresVersion/data/postgresql.conf
# postgresHome=/var/lib/pgsql/$postgresVersion
# postgresBin=/usr/pgsql-$postgresVersion/bin
password=PutYourPasswordHere

function printHelp() {
  printf "Usage:\n"
  printf "${progName} [OPTION]\n\n"
  printf "Options:\n"
  printf "\t -c <Container Name>\t\t\tname of the container/cluster (required)\n"
  printf "\t -p <Primary Server>\t\t\thost where the primary server is running on (required)\n"
  printf "\t -s <Standby Server>\t\t\thost where the standby server is running on (required)\n"
  printf "\t -v <PostgreSQL Major Release>\t\tMajor Release Number 14 default (required)\n"
  printf "\t -h <Help>\t\t\t\tprints this help\n"
}

while getopts c:p:s:v:h option 2>/dev/null
do
  case "${option}"
  in
  c) container=${OPTARG};;
  p) primServer=${OPTARG};;
  s) secdServer=${OPTARG};;
  v) postgresVersion=${OPTARG:=14};;
  h) printHelp; exit 2;;
  *) printf "Unsupported option or parameter value missing '$*'\n"; 
     printf "Run ${progName} -h to print help\n"; exit 1;;
  esac
done

### Building Definitions according to inputs ###
repmgr_conf=/etc/repmgr/$postgresVersion/repmgr.conf
pgData=/pgdata/$postgresVersion/data
postgresConf=/pgdata/$postgresVersion/data/postgresql.conf
postgresHome=/var/lib/pgsql/$postgresVersion
postgresBin=/usr/pgsql-$postgresVersion/bin

rootDir=/opt/pgsql

############ Log function ############

logFile=/tmp/repSecondary_install.log

function log() {
  echo "$(date +%Y.%m.%d-%H:%M:%S) [$$]$*" | tee -a $logFile
}

if [ -f $logFile ]; then
  continue
else
  touch $logFile
  chmod -R 774 $logFile
  sleep 2
fi

############ MAIN ############
# change cert and key file via alter system set command
# not necessary - will be copied with base dump??
#psql -c "alter system set ssl_cert_file = '/pgdata/security/ssl/${container}.pem'; "
#psql -c "alter system set ssl_key_file = '/pgdata/security/ssl/${container}.key'; "

>$repmgr_conf

log "INFO: Setting node_id=2 in $repmgr_conf"
echo "node_id=2" | tee -a $repmgr_conf
log "INFO: Setting node_name=$secdServer in $repmgr_conf"
echo "node_name=$secdServer" | tee -a $repmgr_conf
log "INFO: Setting conninfo='host=$secdServer.$domain user=repmgr dbname=repmgrdb' in $repmgr_conf"
echo "conninfo='host=$secdServer.$domain user=repmgr dbname=repmgrdb'" | tee -a $repmgr_conf
log "Info: Setting 'use_replication_slots=true'  in $repmgr_conf"
echo "use_replication_slots=true"  | tee -a $repmgr_conf
log "INFO: Setting data_directory='$pgData' in $repmgr_conf"
echo "data_directory='$pgData'" | tee -a $repmgr_conf

#/usr/psql-14/bin repmgrdb repmgr <<EOF

$postgresBin/repmgr -h $primServer.$domain -U repmgr -d repmgrdb -F standby clone 
if [ $? == 0 ]; then
  log "INFO: Registering standby returned $?"
else
  log "ERROR: Registering standby returned $?"
  exit 8
fi
#start postgresql
sudo systemctl start postgresql-${postgresVersion}.service

## # set path
## psql -c "ALTER USER repmgr SET search_path TO repmgr, public;"
## log "INFO: ALTER USER repmgr SET search_path TO repmgr, public;"

#register standby
$postgresBin/repmgr standby register

echo "setup of standby successfully completed"