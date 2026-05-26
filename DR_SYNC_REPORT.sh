#!/bin/bash

############################################
# CONFIGURATION
############################################
DB_CONN='/ as sysdba'

MAIL_TO='TcsOracleDba@gehealthcare.com'
HOST_NAME=$(hostname | awk -F '.' '{print $1}')
MAIL_SUBJECT='DR SYNC REPORT - PRD3MES / PRD4MES'
TMP_HTML=/u01/app/oracle/admin/DR_SYNC_REPORT/DR_SYNC_REPORT_$$.html
NORMAL_HTML='<span style="background-color: green; display:block;"> NORMAL </span>'
CRITICAL_HTML='<span style="background-color: red; display:block; color: white"> CRITICAL </span>'
WARNING_HTML='<span style="background-color: yellow; display:block;"> WARNING </span>'

#sqlplus -s "$DB_CONN" <<EOF
#SET PAGESIZE 500
#SET LINESIZE 350
#SET SPOOL ON
#SET FEEDBACK OFF
#SET LINESIZE 32767
#SET ECHO OFF

#SPOOL ${TMP_HTML} APPEND

#PROMPT <h2 style="color:black;">DR SYNC Report</h2>
#PROMPT <hr>

#SPOOL OFF
#EXIT
#EOF

cat << EOF > ${TMP_HTML}
<h2 style="color:black;">DR SYNC Report</h2>
<hr>
EOF

for inst in "$@"; do
ORACLE_SID=$inst
ORACLE_HOME=/u01/app/oracle/product/19.3.0.0/dbee_1
PATH=$ORACLE_HOME/bin:$PATH

export ORACLE_SID
export ORACLE_HOME
export PATH
############################################
# GENERATE HTML REPORT
############################################
$ORACLE_HOME/bin/sqlplus -s "$DB_CONN" <<EOF

SET PAGESIZE 500
SET LINESIZE 350
SET MARKUP HTML ON SPOOL ON PREFORMAT OFF ENTMAP OFF
SET FEEDBACK OFF
SET LINESIZE 32767
SET ECHO OFF

SPOOL ${TMP_HTML} APPEND


PROMPT <p><b>Host / Instance:</b> $(hostname) / ${inst} </p>
PROMPT <p><b>Date:</b> $(date) </p>
PROMPT <h2 style="color:black;">DR SYNC STATUS FOR ${inst}</h2>
PROMPT <br>

SELECT
  name,
  value,
  CASE
  WHEN TO_DSINTERVAL(value) > INTERVAL '3600' SECOND THEN '${CRITICAL_HTML}'
  WHEN TO_DSINTERVAL(value) > INTERVAL '1200' SECOND THEN '${WARNING_HTML}'
  ELSE '${NORMAL_HTML}'
  END STATUS
FROM v\$dataguard_stats
WHERE name in ('transport lag','apply lag');

PROMPT <hr>

SPOOL OFF
EXIT
EOF
done

#echo "Please find the DR SYNC REPORT - PRD3MES / PRD4MES" | mailx -s 'DR SYNC REPORT - PRD3MES / PRD4MES' -a $TMP_HTML $MAIL_TO

printf "From:${HOST_NAME}@gehealthcare.com\nTo:%s\nSubject:DR SYNC REPORT - PRD3MES / PRD4MES\nContent-Type: text/html\n" "$MAIL_TO" | cat - $TMP_HTML | /usr/lib/sendmail -t
