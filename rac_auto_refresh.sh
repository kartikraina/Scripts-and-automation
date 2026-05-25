#script to refresh RAC to RAC from production using active duplication
#  usage : /u01/app/oracle/admin/rac_auto_refresh.sh sid unq_name >> /u01/app/oracle/admin/brk1mes/audit/brk1mes_db_refresh_$(date +%d_%m_%Y_%H%M%S).log 2>&1 &
#
###############################################
#set -x
#clear
echo "*************************************************************************"
echo "====>Script rac_auto_refresh.sh Starting on" `date`
echo "*************************************************************************"

export ORACLE_SID=$1
export DB_UNIQUE_SID=$2

. /home/oracle/bin/$ORACLE_SID

. $DBA_HOME/refresh_params_${ORACLE_SID}.lst

export REFRESH_LOC=${SID_HOME}/db_auto_refresh_$(date +%d%m%Y)_$$

AUX_DB=$DB_UNIQUE_SID
TARGET_DB=$TARGET_DB

#echo
#echo "=====> starting local listener for RMAN active duplication"
#echo

#lsnrctl start lstn$1
#apps_mail_list="Subhra.Prakash@ge.com,gtsshrd.ortm@ge.com,Pavan.Gotety@ge.com,vijayaraghavendra.palle@ge.com"
mail_list="kartik.raina@gehealthcare.com TcsOracleDba@gehealthcare.com"

generate_sys_password_file()
{
echo "$ORACLE_HOME/bin/orapwd file=$DB_CREATE_FILE_DEST dbuniquename=$ORACLE_UNQNAME password=********* force=y"

$ORACLE_HOME/bin/orapwd file=$DB_CREATE_FILE_DEST dbuniquename=$ORACLE_UNQNAME password=\"$SRC_DB_PSWD\" force=y
}

generate_rman_cmd_file()
{
LOG_DIR=$REFRESH_LOC
LOG_FILE=${LOG_DIR}/rman_dup_cmd_file_generation.log
SRC_CHANNELS=$SRC_CHANNELS
AUX_CHANNELS=$AUX_CHANNELS
SRC_DB_PSWD=\"$SRC_DB_PSWD\"
SRC_TNS_NAME="$SRC_TNS_NAME"
#export DUP_CMD_FILE=${LOG_DIR}/rman_dup_${AUX_DB}_$$.cmd
#export DUP_LOG=${LOG_DIR}/rman_dup_${AUX_DB}_$$.log
export ALLOCATE_AUX_CHANNEL_CMD=${LOG_DIR}/rman_allocate_aux_channels_${AUX_DB}.cmd
#export RELEASE_AUX_CHANNEL_CMD=${LOG_DIR}/rman_release_aux_channels_${AUX_DB}.cmd
export ALLOCATE_SRC_CHANNEL_CMD=${LOG_DIR}/rman_allocate_src_channels_${AUX_DB}.cmd
#export RELEASE_SRC_CHANNEL_CMD=${LOG_DIR}/rman_release_src_channels_${AUX_DB}.cmd

echo "for channel in {1..${SRC_CHANNELS}}; do echo allocate channel src\$channel device type disk\;${echo}; done;" | cat > $ALLOCATE_SRC_CHANNEL_CMD
#echo "for channel in {1..${SRC_CHANNELS}}; do echo release channel src\$channel\;${echo}; done;" | cat > $RELEASE_SRC_CHANNEL_CMD

SRC_TNS="connect target 'sys/${SRC_DB_PSWD}@${SRC_TNS_NAME}'"

AUX_TNS="connect auxiliary 'sys/${SRC_DB_PSWD}'"

echo START_TIME : $(date) >> $LOG_FILE

echo RMAN active duplication script creation in progress... >> $LOG_FILE

DUP_CMD="duplicate target database to '${AUX_DB}' from active database"

echo "for channel in {1..${AUX_CHANNELS}}; do echo allocate auxiliary channel aux\$channel device type disk\;${echo}; done;" | cat > $ALLOCATE_AUX_CHANNEL_CMD
#echo "for channel in {1..${AUX_CHANNELS}}; do echo release channel aux\$channel\;${echo}; done;" | cat > $RELEASE_AUX_CHANNEL_CMD

echo "
$SRC_TNS
$AUX_TNS
run
{
$(sh $ALLOCATE_SRC_CHANNEL_CMD)
$(sh $ALLOCATE_AUX_CHANNEL_CMD)

$DUP_CMD;

}" | cat >> $DUP_CMD_FILE

chmod u+x $DUP_CMD_FILE

echo "RMAN duplicate cmd file ($DUP_CMD_FILE) creation completed". >> $LOG_FILE

echo END_TIME : $(date) >> $LOG_FILE
}

notifyError()
{
#rm $REFRESH_LOC/err.log.$$
cat ${audit_path}/ora.error.$$ >${audit_path}/err.log.$$
cat $RMAN_LOG_FILE >> ${audit_path}/err.log.$$
mailx -s "Refresh of $ORACLE_UNQNAME failed!" -a ${audit_path}/err.log.$$ $mail_list <${audit_path}/err.log.$$
}

run_cleanup()
{
notifyError;
mv ${audit_path}/ora.error.$$ ${audit_path}/ora.error.$(date +%d%m%y_%H%M%S) > /dev/null 2>&1
#rm ${audit_path}/clone.${ORACLE_SID}.arc.status.$$ > /dev/null 2>&1
#rm ${audit_path}/arch_dest.list.$$ > /dev/null 2>&1
#rm ${audit_path}/arch_fmt.list.$$ > /dev/null 2>&1
#rm ${audit_path}/clone.${ORACLE_SID}.arc.status.$$ > /dev/null 2>&1
#rm $RMAN_LOG_FILE > /dev/null 2>&1
#rm $PREVIEW_LOG_FILE > /dev/null 2>&1
#rm $aux_cmd_file > /dev/null 2>&1
#rm $prev_cmd_file > /dev/null 2>&1
#rm ${clone_file} > /dev/null 2>&1
}
#initfile()
#{
#echo "spfile='/stage/product/oracle/12.1.0.2/dbs/spfileswps.ora'" > /stage/dba/oracle/swps/pfile/initswps1.ora
#}
drop_aux()
{
echo "====>Collecting relevant information before drop."
echo
$ORACLE_HOME/bin/sqlplus /nolog <<EOF
    connect / as sysdba
    spool $REFRESH_LOC/pwfile_users.$$.lst
    set line 200
    select * from v\$pwfile_users;
    spool off
    exit
EOF

echo "====>Shutting down and Starting $AUX_DB in NOMOUNT mode for duplication"
echo
$ORACLE_HOME/bin/sqlplus /nolog <<EOF >${audit_path}/ora.error.$$
connect / as sysdba
create pfile='$ORACLE_HOME/dbs/init$ORACLE_SID.ora.refresh.$$' from spfile;
host cp $ORACLE_HOME/dbs/init$ORACLE_SID.ora.refresh.$$ $ORACLE_HOME/dbs/init$ORACLE_SID.ora.bkp.$$
alter system set cluster_database=false scope=spfile sid='*';
alter system set DB_CREATE_FILE_DEST='${DB_CREATE_FILE_DEST}' scope=spfile sid='*';
alter system set DB_CREATE_ONLINE_LOG_DEST_1='${DB_CREATE_ONLINE_LOG_DEST_1}' scope=spfile sid='*';
alter system set DB_CREATE_ONLINE_LOG_DEST_2='${DB_CREATE_ONLINE_LOG_DEST_2}' scope=spfile sid='*';
create pfile='$ORACLE_HOME/dbs/init$ORACLE_SID.ora.tmp.$$' from spfile;
spool $REFRESH_LOC/password_backup_$$.sql
set head off feed off
select 'ALTER USER "'|| username ||'" identified by values '''||b.password||''';' from dba_users a, user$ b where a.username=b.name and a.username in (select username from dba_users where username like  '%%' )  ;
spool off
exit
EOF

echo " Database Status "
$ORACLE_HOME/bin/srvctl status database -d $DB_UNIQUE_SID -v
#    $ORACLE_HOME/bin/sqlplus /nolog << EOF >> ${audit_path}/ora.error.$$
#   connect / as sysdba
#    select name,open_mode,controlfile_type,database_role from v\$database;
#    exit
#EOF

echo   "                                      "

echo " shutting down database at `date` "

echo "                                      "
$ORACLE_HOME/bin/srvctl stop database -d $DB_UNIQUE_SID
#    $ORACLE_HOME/bin/sqlplus /nolog << EOF
#   connect / as sysdba
#   shut immediate;
#    exit
#EOF
echo "                                      "

echo " database down at `date` "

echo "                                      "
#srvctl stop database -d $DB_UNIQUE_SID
echo "                                      "

echo " starting up database in exclusive restrict mount mode at `date` "
echo "                                      "
$ORACLE_HOME/bin/sqlplus /nolog << EOF >> ${audit_path}/ora.error.$$
connect / as sysdba
STARTUP MOUNT EXCLUSIVE RESTRICT;
exit;
EOF
echo "                                      "

grep "ORA-" ${audit_path}/ora.error.$$|grep -v ORA-01109|grep -v ORA-32004
if [ $? -eq 0 ]; then
	 RMAN_LOG_FILE=${audit_path}/ora.error.$$
     echo "#####################################################"
     echo "## ERROR ====> Startup of Oracle failed                ##"
     echo "##       ====> Duplication of $AUX_DB can not continue ##"
     cat ${audit_path}/ora.error.$$ | grep ORA- | awk '{print "##", $0}'
     echo "#####################################################"
     run_cleanup;
  exit 1
fi
RMAN_LOG_FILE=${audit_path}/drop_aux_$$.log
#$ORACLE_HOME/bin/rman log=$RMAN_LOG_FILE << EOF
#STARTUP MOUNT EXCLUSIVE RESTRICT;
#DROP DATABASE NOPROMPT;
#exit;
#EOF
echo " dropping database $AUX_DB at `date` "
echo
$ORACLE_HOME/bin/sqlplus /nolog << EOF >> $RMAN_LOG_FILE
connect / as sysdba
DROP DATABASE;
exit;
EOF

grep -q -e RMAN- -e ORA- $RMAN_LOG_FILE
     if [ $? -eq 0 ]; then
        echo "##########################################################"
        echo "## ERROR ====> Drop of AUX database failed    ##"
        echo "##       ====> Resolve any errors before resubmitting   ##"
        echo "##########################################################"
        run_cleanup;exit 1
     else
        echo
        echo "====>Successfully dropped $AUX_DB "
        echo
     fi
}
clone_aux()
{
echo "====>Creating sys passwordfile of $AUX_DB for duplication"
generate_sys_password_file;
echo "												"
echo "====>Starting $AUX_DB in NOMOUNT mode for duplication"
echo
    $ORACLE_HOME/bin/sqlplus /nolog <<EOF > ${audit_path}/ora.error.$$
    connect / as sysdba
    startup nomount pfile='$ORACLE_HOME/dbs/init$ORACLE_SID.ora.tmp.$$';
    exit
EOF
grep "ORA-" ${audit_path}/ora.error.$$ | grep -v "ORA-01507"
if [ $? -eq 0 ]; then
     echo "#####################################################"
     echo "## ERROR ====> Startup of Oracle failed                ##"
     echo "##       ====> Duplication of $AUX_DB can not continue ##"
     cat ${audit_path}/ora.error.$$ | grep ORA- | awk '{print "##", $0}'
     echo "#####################################################"
     run_cleanup;exit 1
fi

$ORACLE_HOME/bin/sqlplus /nolog <<EOF > ${audit_path}/ora.error.$$
    connect / as sysdba
	create spfile='$ORACLE_HOME/dbs/spfile$ORACLE_SID.ora' from pfile='$ORACLE_HOME/dbs/init$ORACLE_SID.ora.tmp.$$';
	shutdown immediate;
	startup nomount;
    exit
EOF

#RMAN_LOG_FILE=${audit_path}/clone_aux.log
RMAN_LOG_FILE=${audit_path}/rman_dup_${AUX_DB}_$$.log
DUP_CMD_FILE=${audit_path}/rman_dup_${AUX_DB}_$$.cmd
echo Using cmd file $DUP_CMD_FILE >> $RMAN_LOG_FILE
generate_rman_cmd_file;
$ORACLE_HOME/bin/rman cmdfile=$DUP_CMD_FILE log=$RMAN_LOG_FILE
grep  -e RMAN- -e ORA- $RMAN_LOG_FILE|grep -v RMAN-05529|grep -v RMAN-07518
     if [ $? -eq 0 ]; then
        grep  -e "Finished Duplicate " $RMAN_LOG_FILE
     fi
     if [ $? -eq 1 ]; then
        echo "##########################################################"
        echo "## ERROR ====> Duplication of target database failed    ##"
        echo "##       ====> Resolve any errors before resubmitting   ##"
        echo "##########################################################"
        run_cleanup;exit 1
     else
        echo
        echo "====>Successfully duplicated $AUX_DB from $TARGET_DB"
        echo
     fi
}
#Locations
#scripts_path=$DBA_HOME/admin
audit_path=$REFRESH_LOC

###########
#Connections
###########
RMAN=$ORACLE_HOME/bin/rman

################################################################################
##  ------------------------------------------------------------------------  ##
##                        MAIN SCRIPT EXECUTION                               ##
##  ------------------------------------------------------------------------  ##
################################################################################

mkdir -p $REFRESH_LOC
chmod 777 $REFRESH_LOC
drop_aux;
clone_aux;
tail -10 $RMAN_LOG_FILE |mailx -s "Refresh completed for $ORACLE_UNQNAME@$(hostname | awk -F '.' '{print $1}')." -a $RMAN_LOG_FILE $mail_list

#tail -10 $RMAN_LOG_FILE |mailx -s "Refresh successfull for $ORACLE_UNQNAME@$(hostname | awk -F '.' '{print $1}') . Please verify and let us know if you have any issues." $app_mail_list

#. /home/oracle/bin/oemagent
#emctl stop blackout <BLACKOUT_NAME>

#echo "=====> stopping local listener "
#echo
#
#lsnrctl stop lstn$1

export AUX_DB_PSWD=\"$AUX_DB_PSWD\"

echo "====>Shutting down and creating spfile"
echo
    sqlplus /nolog <<EOF >${audit_path}/ora.error.$$
    connect / as sysdba
    shut immediate
    startup mount;
    alter database noarchivelog;
    alter database open;
    set echo on
	spool ${audit_path}/password_reset_$$.log
	@${audit_path}/password_backup_$$.sql
    --spool /stage/backup/oracle/export/swps/password_reset.log
    --@/stage/backup/oracle/export/swps/password_backup.sql
    spool off
	alter user sys identified by ${AUX_DB_PSWD};
    --host cp $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora.tmp.$$ $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora.tmp.$$_bkp
    --host rm $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora
	alter system set cluster_database=true scope=spfile sid='*';
	create pfile='$ORACLE_HOME/dbs/init$ORACLE_SID.ora.post_refresh.$$' from spfile;
    create spfile='${DB_CREATE_FILE_DEST}' from pfile='$ORACLE_HOME/dbs/init$ORACLE_SID.ora.post_refresh.$$';
    shut immediate
    exit
EOF

echo "====>Shutting down and Starting database on all available RAC nodes"

$ORACLE_HOME/bin/srvctl status database -d $DB_UNIQUE_SID -v
#srvctl modify database -d $DB_UNIQUE_SID -v -p +DATA/swps/parameterfile/spfileswps.ora
#echo "spfile='+DATA/swps/PARAMETERFILE/spfileswps.ora'"  > /stage/dba/oracle/swps/pfile/initswps1.ora

echo "====> ----------------------------------------"

$ORACLE_HOME/bin/srvctl start database -d $DB_UNIQUE_SID

echo "====> ----------------------------------------"

$ORACLE_HOME/bin/srvctl status database -d $DB_UNIQUE_SID -v

clear
echo "*************************************************************************"
echo "====>Script rac_auto_refresh.sh Ending on" `date`
echo "*************************************************************************"
