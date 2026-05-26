#!/bin/bash

############################################
# CONFIGURATION
############################################
DB_CONN='/ as sysdba'

ORACLE_SID=$1
ORACLE_HOME=$(cat /etc/oratab | grep -e $ORACLE_SID | grep -v \#|grep -v \*|awk -F ':' '{print $2}')
PATH=$ORACLE_HOME/bin:$PATH

export ORACLE_SID
export ORACLE_HOME
export PATH

#MAIL_TO='TcsOracleDba@gehealthcare.com'
MAIL_TO='kartik.raina@gehealthcare.com'
HOST_NAME=$(hostname | awk -F '.' '{print $1}')
#MAIL_SUBJECT='RITM0577218 | FRA USAGE REPORT FOR ${ORACLE_SID}'
LOG_LOC=/u01/app/oracle/admin/FRA_USAGE_REPORT
TMP_HTML=${LOG_LOC}/FRA_USAGE_REPORT_${ORACLE_SID}_$$.html
NORMAL_HTML='<span style="background-color: green; display:block;"> NORMAL </span>'
CRITICAL_HTML='<span style="background-color: red; display:block; color: white"> CRITICAL </span>'
WARNING_HTML='<span style="background-color: yellow; display:block;"> WARNING </span>'
GRP_CHECK_LOG=$LOG_LOC/check_grp_exists_$$.log

$ORACLE_HOME/bin/sqlplus -s "$DB_CONN" <<EOF
SET HEAD OFF FEED OFF
SET LINESIZE 350
SET FEEDBACK OFF
SET LINESIZE 32767
SET ECHO OFF

SPOOL $GRP_CHECK_LOG

SELECT RTRIM(NAME) FROM V\$RESTORE_POINT;

SPOOL OFF
EOF

grp_count=$(cat $GRP_CHECK_LOG | wc -w)

############################################
# GENERATE HTML REPORT
############################################
if (( grp_count > 0 ))
then
$ORACLE_HOME/bin/sqlplus -s "$DB_CONN" <<EOF

SET PAGESIZE 500
SET LINESIZE 350
SET MARKUP HTML ON SPOOL ON PREFORMAT OFF ENTMAP OFF
SET FEEDBACK OFF
SET LINESIZE 32767
SET ECHO OFF

SPOOL ${TMP_HTML} APPEND

PROMPT <h2 style="color:black;">FRA USAGE Report</h2>
PROMPT <hr>
PROMPT <p><b>Host / Instance:</b> $(hostname) / ${ORACLE_SID} </b></p>
PROMPT <p><b>Date:</b> $(date) </b></p>
PROMPT <h2 style="color:black;">FRA USAGE Status for ${ORACLE_SID}</h2>
PROMPT <br>
PROMPT <hr>

PROMPT <p><b>Allocated Size: </b></p>

select a.value as "FRA LOCATION", b.value/1024/1024/1024 as "FRA SIZE GB"
from v\$parameter a , v\$parameter b
where a.name='db_recovery_file_dest' and b.name='db_recovery_file_dest_size';

PROMPT <hr>

PROMPT <p><b>GRP Information: </b></p>

select name,to_char(TIME,'DD Mon YYYY hh:mm:ss') as "CREATED ON" from v\$restore_point;

PROMPT <hr>

PROMPT <p><b>FRA STATUS: </b></p>

SELECT
FILE_TYPE,
PERCENT_SPACE_USED,
CASE
WHEN PERCENT_SPACE_USED > 80 THEN '${CRITICAL_HTML}'
WHEN PERCENT_SPACE_USED > 50 THEN '${WARNING_HTML}'
ELSE '${NORMAL_HTML}'
END STATUS,
PERCENT_SPACE_RECLAIMABLE,
NUMBER_OF_FILES
FROM V\$RECOVERY_AREA_USAGE;

PROMPT <hr>

PROMPT <p><b>OVERALL STATUS: </b></p>

SELECT 
CASE
WHEN SUM(PERCENT_SPACE_USED) > 80 THEN '${CRITICAL_HTML}'
WHEN SUM(PERCENT_SPACE_USED) > 50 THEN '${WARNING_HTML}'
ELSE '${NORMAL_HTML}'
END AS "OVERALL FRA STATUS" FROM V\$RECOVERY_AREA_USAGE;

SPOOL OFF
EXIT
EOF
printf "From:${HOST_NAME}@gehealthcare.com\nTo:%s\nSubject:FRA USAGE REPORT FOR ${ORACLE_SID}\nContent-Type: text/html\n" "$MAIL_TO" | cat - $TMP_HTML | /usr/sbin/sendmail -t
fi