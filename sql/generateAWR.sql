set echo off 
set feedback off
set timing off
set pagesize 0
set linesize 15000
set trimspool on
set show off
set verify off
set heading off

define V_BID=&1
define V_EID=&2
define AWRFILE_NAME=&3

col dbid new_value V_DBID noprint
select dbid from v$database;

col instance_number new_value V_INST noprint
select instance_number from v$instance;

spool &&AWRFILE_NAME
select output from table(dbms_workload_repository.awr_report_html(&&V_DBID, &&V_INST, &&V_BID, &&V_EID, 0));
spool off
/
exit;
