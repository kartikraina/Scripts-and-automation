INSTALL_LOG_LOCATION=/u01/app/oracle/admin
NODE_LIST='usatllsorarac01,usatllsorarac02'
DB_UNQ_NAME='stg1otds'
DB_TYPE='MULTIPURPOSE'
DB_NAME='stg1otds'
DB_SID_NAME='stg1otds1'
DB_HOME=/u01/app/oracle/product/19.3.0.0/dbee_1
ORA_BASE=/u01/app/oracle
DB_SYS_PASSWORD='BLa2ZP$m8R%QeDkH'
DB_SYSTEM_PASSWORD='AqT5#L9mRSeKpU_D'
DB_STORAGE_TYPE='ASM'
DATAFILE_DEST='+STG1OTDS_DG'
ARCH_DEST='+ORAATL1S_ARCH_DG'
ASMSNMP_PASSWORD="BLa2ZP$m8R%QeDkH"
DB_CHARSET='AL32UTF8'
DB_NCHARSET='AL16UTF16'
ENABLE_ARCHIVE='false'
ONLINE_LOG_FILE_SIZE_IN_MB=500

DB_BLK_SIZE_IN_BYTES=8192
UNDO_TB='UNDOTBS1'
SGA_TGT='5GB'
SGA_LMT='5GB'
MAX_DB_FILES=1000
NLS_LANG='AMERICAN'
DIAGNOSTIC_DEST=/u01/app/oracle/admin
AUDIT_DEST=/u01/app/oracle/admin/${DB_UNQ_NAME}/adump
PROCESSES=2000
PGA_TGT='3000M'
NLS_TERRITORY='AMERICA'
COMPATIBLE='19.0.0'

## usage: dbca_create_db_SI_19c.sh <FULL_PATH_OF_PARAMS_FILE>

set -e

DATE_TIME=$(date '+%d_%m_%Y_%H-%M-%S')

CREATE_DB_PARAMS_FILE=$1

. ${CREATE_DB_PARAMS_FILE}

RESPONSE_FILE=$INSTALL_LOG_LOCATION/dbca_create_db_${DB_UNQ_NAME}.rsp

echo "Creating DB response file for DB ${DB_UNQ_NAME} ..." >> $INSTALL_LOG_LOCATION/${DB_UNQ_NAME}_dbca.log

cat >> $RESPONSE_FILE << ORA_EOF
responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
gdbName=$DB_UNQ_NAME
sid=$DB_SID_NAME
databaseConfigType=RAC
RACOneNodeServiceName=
policyManaged=false
createServerPool=false
serverPoolName=
cardinality=
force=false
pqPoolName=
pqCardinality=
createAsContainerDatabase=false
numberOfPDBs=0
pdbName=
useLocalUndoForPDBs=true
pdbAdminPassword=
nodelist=$NODE_LIST
templateName=${DB_HOME}/assistants/dbca/templates/General_Purpose.dbc
sysPassword=$DB_SYS_PASSWORD
systemPassword=$DB_SYSTEM_PASSWORD
emConfiguration=NONE
emExpressPort=5500
runCVUChecks=FALSE
dbsnmpPassword=
omsHost=
omsPort=0
emUser=
emPassword=
dvConfiguration=false
dvUserName=
dvUserPassword=
dvAccountManagerName=
dvAccountManagerPassword=
olsConfiguration=false
datafileJarLocation={ORACLE_HOME}/assistants/dbca/templates/
storageType=$DB_STORAGE_TYPE
asmsnmpPassword=$ASMSNMP_PASSWORD
recoveryGroupName=
characterSet=$DB_CHARSET
nationalCharacterSet=$DB_NCHARSET
registerWithDirService=false
dirServiceUserName=
dirServicePassword=
walletPassword=
skipListenerRegistration=false
variablesFile=
variables=ORACLE_BASE_HOME=$DB_HOME,DB_UNIQUE_NAME=$DB_UNQ_NAME,ORACLE_BASE=$ORA_BASE,PDB_NAME=,DB_NAME=$DB_NAME,ORACLE_HOME=$DB_HOME,SID=$DB_SID_NAME
initParams=sga_target=$SGA_TGT,db_files=$MAX_DB_FILES,db_block_size=${DB_BLK_SIZE_IN_BYTES}BYTES,nls_language=$NLS_LANG,diagnostic_dest=$DIAGNOSTIC_DEST,remote_login_passwordfile=exclusive,db_create_file_dest=$DATAFILE_DEST,audit_file_dest=$AUDIT_DEST,processes=$PROCESSES,pga_aggregate_target=$PGA_TGT,nls_territory=$NLS_TERRITORY,db_name=$DB_NAME,audit_trail=db,db_create_online_log_dest_1=$DATAFILE_DEST,db_create_online_log_dest_2=$ARCH_DEST,log_archive_dest_1='LOCATION=${ARCH_DEST}'
sampleSchema=false
memoryPercentage=40
databaseType=$DB_TYPE
automaticMemoryManagement=false
totalMemory=0
ORA_EOF

echo "Response file created at location: $INSTALL_LOG_LOCATION/dbca_create_db_${DB_UNQ_NAME}.rsp ..." >> $INSTALL_LOG_LOCATION/${DB_UNQ_NAME}_dbca.log

echo "Starting Database Creation..." >> $INSTALL_LOG_LOCATION/${DB_UNQ_NAME}_dbca.log

$DB_HOME/bin/dbca -createDatabase -responseFile ${RESPONSE_FILE} -enableArchive $ENABLE_ARCHIVE -redoLogFileSize $ONLINE_LOG_FILE_SIZE_IN_MB -silent >> $INSTALL_LOG_LOCATION/${DB_UNQ_NAME}_dbca.log 2>&1

echo "Database creation Completed." >> $INSTALL_LOG_LOCATION/${DB_UNQ_NAME}_dbca.log