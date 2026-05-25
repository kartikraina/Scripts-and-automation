#export CURR_SESS_PID=$$

#set -e

export ORACLE_SID=$1

export ORAENV_ASK=NO

. /usr/local/bin/oraenv

unset ORAENV_ASK

. ~/bin/$ORACLE_SID

. $DBA_HOME/dev2pds_table_auto_refresh_params.lst

export LOG_DIR=$DBA_HOME/dev2pds_table_auto_refresh_dnd

MAIL_LIST='kartik.raina@gehealthcare.com'

{
tmp_var=$(mktemp /tmp/XXXXX)

if [ $? -eq 0 ]; then
export UNIQUE_ID=${tmp_var##*/}
export DATE_UID=$(date +%d%m)_$UNIQUE_ID
else
echo "Unable to create UNIQUE ID for the session." | mailx -s "Refresh Failed for dev2pds@$(hostname -f | awk -F '.' '{print $1}')" $MAIL_LIST
exit 1
fi
}

export DB_DIRECTORY=DIR_$DATE_UID

export WORKING_DIRECTORY=${LOG_DIR}/$DATE_UID

mkdir -p $WORKING_DIRECTORY

cat >> $LOG_DIR/dev2pds_table_refresh_auto_$DATE_UID.log << +++
$(
echo "Start Time : $(date)"
echo 
echo "Current Unique Session ID: $UNIQUE_ID"

echo

echo "... Capturing pre refresh table row count in file ($WORKING_DIRECTORY/pre_check_table_row_count_$DATE_UID.lst) ..."

$ORACLE_HOME/bin/sqlplus /nolog << EOF
connect / as sysdba
set line 200 pages 20 echo off
col owner for a20
col table_name for a40
spool $WORKING_DIRECTORY/pre_check_table_row_count_$DATE_UID.lst
select owner, table_name, num_rows from dba_tables where table_name in ('GE_INBD_SPM_PLN_LVL',
'GE_INBD_SPM_ONHAND_BALANCE',
'GE_INBD_SPM_LOCATION',
'GEHC_KINAXIS_TMP',
'GE_INBD_PLAN_ORDER',
'GE_SPM_SUPP_FRCST_PO_DETAILS',
'GE_SPM_GLP_PART_DEMAND_OPEN',
'GE_INBD_SPM_DMD_FORECAST');
spool off;
EOF

echo

echo "... Creating target db table export par file ($WORKING_DIRECTORY/expdp_dev2pds_tables_$DATE_UID.par) ..."

cat > $WORKING_DIRECTORY/expdp_dev2pds_tables_$DATE_UID.par << EOF
userid='/ as sysdba'
directory=$DB_DIRECTORY
dumpfile=expdp_dev2pds_tables_$DATE_UID.dmp
logfile=expdp_dev2pds_tables_$DATE_UID.log
schemas=PDS
include=table:"IN ('GE_INBD_SPM_PLN_LVL',
'GE_INBD_SPM_ONHAND_BALANCE',
'GE_INBD_SPM_LOCATION',
'GEHC_KINAXIS_TMP',
'GE_INBD_PLAN_ORDER',
'GE_SPM_SUPP_FRCST_PO_DETAILS',
'GE_SPM_GLP_PART_DEMAND_OPEN',
'GE_INBD_SPM_DMD_FORECAST')"
cluster=n
flashback_time=systimestamp
EOF

echo

echo "... Creating table refresh network import parfile ($WORKING_DIRECTORY/impdp_pds_table_refresh_$DATE_UID.par) ..."

cat > $WORKING_DIRECTORY/impdp_pds_table_refresh_$DATE_UID.par << EOF
userid='/ as sysdba'
directory=$DB_DIRECTORY
logfile=impdp_pds_table_refresh_$DATE_UID.log
schemas=PDS
include=table:"IN ('GE_INBD_SPM_PLN_LVL',
'GE_INBD_SPM_ONHAND_BALANCE',
'GE_INBD_SPM_LOCATION',
'GEHC_KINAXIS_TMP',
'GE_INBD_PLAN_ORDER',
'GE_SPM_SUPP_FRCST_PO_DETAILS',
'GE_SPM_GLP_PART_DEMAND_OPEN',
'GE_INBD_SPM_DMD_FORECAST')"
network_link=prdpds_system
table_exists_action=replace
cluster=n
flashback_time=systimestamp
EOF

echo 

echo ... Creating DB Directory for refresh ...

echo

$ORACLE_HOME/bin/sqlplus /nolog << EOF
connect / as sysdba
create directory $DB_DIRECTORY as '${WORKING_DIRECTORY}';
grant read,write on directory $DB_DIRECTORY to sys,system;
prompt Directory $DB_DIRECTORY created.
exit
EOF

echo 

echo ... Locking the PDS user ...

@ORACLE_HOME/bin/sqlplus /nolog << EOF
connect / as sysdba
alter user PDS account lock;
EOF

echo

echo ... Starting Target Tables backup ...

$ORACLE_HOME/bin/expdp parfile=$WORKING_DIRECTORY/expdp_dev2pds_tables_$DATE_UID.par

echo 

echo ... Updating DB link for network refresh ...

$ORACLE_HOME/bin/sqlplus /nolog << EOF
connect / as sysdba
DECLARE
  l_count NUMBER;
BEGIN
  -- Check if DB link exists
  SELECT COUNT(*)
  INTO   l_count
  FROM   dba_db_links
  WHERE  db_link = 'PRDPDS_SYSTEM';

  -- Drop if exists
  IF l_count > 0 THEN
    EXECUTE IMMEDIATE 'DROP DATABASE LINK PRDPDS_SYSTEM';
  END IF;

  -- Create DB link
  EXECUTE IMMEDIATE q'[
    CREATE DATABASE LINK PRDPDS_SYSTEM
    CONNECT TO system
    IDENTIFIED BY "$SRC_DB_PSWD"
    USING '$SRC_TNS_NAME'
  ]';
END;
/
EOF

echo 

echo ... Starting PDS tables network refresh from prod ...

$ORACLE_HOME/bin/impdp parfile=$WORKING_DIRECTORY/impdp_pds_table_refresh_$DATE_UID.par

echo

echo ... Unlocking the PDS User ...

@ORACLE_HOME/bin/sqlplus /nolog << EOF
connect / as sysdba
alter user PDS account unlock;
EOF

echo

echo "End Time : $(date)"
)
+++

#echo Kindly review the attached import file. | mailx -s "Refresh Completed for dev2pds@$(hostname -f | awk -F '.' '{print $1}')" -a $WORKING_DIRECTORY/expdp_dev2pds_tables_$DATE_UID.log $MAIL_LIST

echo Kindly review the attached import file.  | mailx -s "Refresh Completed for dev2pds@$(hostname -f | awk -F '.' '{print $1}')" -a $WORKING_DIRECTORY/impdp_pds_table_refresh_$DATE_UID.log $MAIL_LIST
