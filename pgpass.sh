#!/bin/sh

########################################
#                                      #
#  pgpass setup script                 #
#                                      #
#  Author: Karsten Lenz / 2020.05.28   #
#                                      #
########################################

progName=$(basename $0)
# postgresVersion=12
domain=localdomain
# pgData=/pgdata/$postgresVersion/data
# postgresConf=/pgdata/$postgresVersion/data/postgresql.conf
postgresHome=/var/lib/pgsql
# postgresBin=/usr/pgsql-$postgresVersion/bin
pgpass=$postgresHome/.pgpass
password=PutYourPasswordHere

function printHelp() {
  printf "Usage:\n"
  printf "${progName} [OPTION]\n\n"
  printf "Options:\n"
  printf "\t -p <Primary Server>\t\t\tserver where the primary host is running on (required)\n"
  printf "\t -s <Secondary Server>\t\t\tserver where the secondary host is running on (required)\n"
  printf "\t -h <Help>\t\t\t\tprints this help\n"
}

while getopts p:s:h option 2>/dev/null
do
  case "${option}"
  in
  p) primServer=${OPTARG};; 
  s) secdServer=${OPTARG};;
  h) printHelp; exit 2;;
  *) printf "Unsupported option or parameter value missing '$*'\n"; 
     printf "Run ${progName} -h to print help\n"; exit 1;;
  esac
done

############ Log function ############

logFile=/tmp/pgpass_install.log

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

#clean .pgpass
rm -f $pgpass

#set values in .pgpass
log "INFO: #host:port:database:user:password in $pgpass"
echo "#host:port:database:user:password" | tee -a $pgpass
log "INFO: Setting localhost in $pgass"
echo "localhost:5432:*:repmgr:$password" | tee -a $pgpass
log "INFO: Setting 127.0.0.1 in $pgpass"
echo "127.0.0.1:5432:*:repmgr:$password" | tee -a $pgpass
log "INFO: Setting Primary $primServer in $pgpass"
echo "$primServer.$domain:5432:*:repmgr:$password" | tee -a $pgpass
log "INFO: Setting Primary $secdServer in $pgpass"
echo "$secdServer.$domain:5432:*:repmgr:$password" | tee -a $pgpass

#set .pgpass 0600
chmod 0600 $pgpass

#export PGPASSFILE
export PGPASSFILE='/var/lib/pgsql/.pgpass'