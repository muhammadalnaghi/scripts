#!/bin/sh

########################################
#  RepMgr setup script                 #
#  Rework: Karsten Lenz / 2022.08.11   #
########################################

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
  printf "\t -p <Primary Server>\t\t\thost where the primary server is running on (required)\n"
  printf "\t -s <Standby Server>\t\t\thost where the standby server is running on (required)\n"
  printf "\t -v <PostgreSQL Major Release>\t\tMajor Release Number default 14 (required)\n"
  printf "\t -h <Help>\t\t\t\tprints this help\n"
}

while getopts c:p:s:v:h option 2>/dev/null
do
  case "${option}"
  in
  p) primServer=${OPTARG};;
  s) secdServer=${OPTARG};;
  v) postgresVersion=${OPTARG:=14};;
  h) printHelp; exit 2;;
  *) printf "Unsupported option or parameter value missing '$*'\n"; 
     printf "Run ${progName} -h to print help\n"; exit 1;;
  esac
done

### Building Variables according to inputs ###
repmgr_conf=/etc/repmgr/$postgresVersion/repmgr.conf
pgData=/pgdata/$postgresVersion/data
postgresConf=/pgdata/$postgresVersion/data/postgresql.conf
postgresHome=/var/lib/pgsql/$postgresVersion
postgresBin=/usr/pgsql-$postgresVersion/bin

rootDir=/opt/pgsql

############ Log function ############

logFile=/tmp/repMaster_install.log

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
psql -c "alter system set max_replication_slots = 10;"
psql -c "alter system set archive_mode = 'on';"
psql -c "alter system set archive_command = '/bin/true';"
psql -c "alter system set wal_level = 'replica';"
psql -c "alter system set max_wal_senders = 2;"
psql -c "create user repmgr with superuser"
log "INFO: create user repmgr with superuser"
psql -c "alter user repmgr with password '$password'"
log "INFO: alter user repmgr set password"

$postgresBin/createdb repmgrdb -O repmgr
log "INFO: Create database repmgrdb with owner repmgr"

$postgresBin/pg_ctl reload -D $pgData -W -s
if [ $? == 0 ]; then
  log "INFO: Reloading postgres returned $?"
else
  log "ERROR: Reloading postgres returned $?"
  exit 8
fi

> $repmgr_conf
#log "INFO: Setting cluster=$repCluster in $repmgr_conf"
#echo "cluster=$repCluster" | tee -a $repmgr_conf
log "INFO: Setting node_id=1 in $repmgr_conf"
echo "node_id=1" | tee -a $repmgr_conf
log "INFO: Setting node_name=$primServer in $repmgr_conf"
echo "node_name=$primServer" | tee -a $repmgr_conf
log "INFO: Setting conninfo='host=$primServer.$domain user=repmgr dbname=repmgrdb' in $repmgr_conf"
echo "conninfo='host=$primServer.$domain user=repmgr dbname=repmgrdb'" | tee -a $repmgr_conf
log "INFO: Setting use_replication_slots=true"
echo "use_replication_slots=true" | tee -a $repmgr_conf
log "INFO: Setting data_directory='$pgData' in $repmgr_conf"
echo "data_directory='$pgData'" | tee -a $repmgr_conf

#/usr/psql-14/bin repmgrdb repmgr <<EOF

psql -c "ALTER USER repmgr SET search_path TO repmgr, public;"
log "INFO: ALTER USER repmgr SET search_path TO repmgr, public;"

$postgresBin/repmgr -f $repmgr_conf -F master register
if [ $? == 0 ]; then
  log "INFO: Registering master returned $?"
else
  log "ERROR: Registering master returned $?"
  exit 8
fi

echo "setup of primary successfully completed"
