#!/bin/bash

echo "PostgreSQL Configuration"
echo ""

function printHelp {
  printf "Usage:\n"
  printf "${progName} [OPTION]\n\n"
  printf "Options:\n"
  printf "\t -c <Count of CPU used>\t\t\tAmount of CPU used by this system (required)\n"
  printf "\t -m <Amount of Memory>\t\t\tAmount of Memory of this system (required)\n"
  printf "\t -o <Max Connections>\t\t\tAmount of Connections of this system (default = 100))\n"
  printf "\t -v <PostgreSQL Version>\t\tMajor Release of Postgresql (default = 14)\n"
  printf "\t -h <Help>\t\t\t\tprints this help\n"
}

while getopts c:m:o:v:h option 2>/dev/null
do
  case "${option}"
  in
  c) CPU=${OPTARG};;
  m) RAM=${OPTARG};;
  o) CONNECTIONS=${OPTARG:=100};;
  v) VERSION=${OPTARG:=14};;
  h) printHelp; exit 2;;
  *) printf "Unsupported option or parameter value missing '$*'\n";
     printf "Run ${printHelp} -h to print help\n"; exit 1;;
  esac
done

# create ssl certificate and ssl key
openssl req -new -newkey rsa:4096 -nodes -x509 -subj "/C=CH/ST=DBAAS/L=ZUERICH/O=Dis/CN=www.dbi-services.com" -keyout /pgdata/ssl/pgsql.key -out /pgdata/ssl/pgsql.crt

# define parameters
rootdir=/opt/pgsql/config
cd ${rootdir}

# connections
max_connections=($CONNECTIONS)
echo max_connections : $max_connections

# memory
let shared_buffers=($RAM/4)
echo shared_buffers : $shared_buffers
let effective_cache_size=($RAM-$shared_buffers)
echo effective_cache_size : $effective_cache_size
let work_mem=($RAM*256/$CONNECTIONS)
echo work_mem : $work_mem
let maintenance_work_mem=($RAM*256/8)
echo  maintenance_work_mem : $maintenance_work_mem

# cpu
let max_worker_processes=($CPU)
echo max_worker_processes : $max_worker_processes
let max_parallel_workers=($CPU)
echo  max_parallel_workers : $max_parallel_workers
let max_parallel_workers_per_gather=($CPU/2)
echo max_parallel_workers_per_gather : $max_parallel_workers_per_gather
let max_parallel_maintenance_workers=($CPU/2)
echo max_parallel_maintenance_workers : $max_parallel_maintenance_workers

# cpu and memory configuration
psql -c "alter system set listen_addresses = '*';"
psql -c "alter system set max_connections = '$max_connections';"
psql -c "alter system set effective_cache_size = '$effective_cache_size GB';"
psql -c "alter system set shared_buffers = '$shared_buffers GB';"
psql -c "alter system set work_mem = '$work_mem MB';"
psql -c "alter system set maintenance_work_mem = '$maintenance_work_mem MB';"
psql -c "alter system set max_worker_processes = '$max_worker_processes';"
psql -c "alter system set max_parallel_workers = '$max_parallel_workers';"
psql -c "alter system set max_parallel_workers_per_gather = '$max_parallel_workers_per_gather';"
psql -c "alter system set max_parallel_maintenance_workers = '$max_parallel_maintenance_workers';"
psql -c "alter system set ssl_cert_file = '/pgdata/ssl/pgsql.crt';"
psql -c "alter system set ssl_key_file = '/pgdata/ssl/pgsql.key';"
psql -c "alter system set ssl = on;"
psql -c "alter system set ssl_ciphers = 'HIGH';"
psql -c "alter system set ssl_min_protocol_version = 'TLSv1.2';"
psql -c "alter system set shared_preload_libraries = pg_stat_statements;"
sudo service postgresql-$VERSION restart
exit 
