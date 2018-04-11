/* To clone a user */
set head off
set pages 0
set long 9999999
select dbms_metadata.get_ddl('USER', 'U193063') from dual
union all
select dbms_metadata.get_granted_ddl('ROLE_GRANT', 'U193063') from dual
union all
select dbms_metadata.get_granted_ddl('SYSTEM_GRANT','U193063') from dual
union all
select dbms_metadata.get_granted_ddl('OBJECT_GRANT','U193063') from dual

-- Template application user
CREATE USER "ICO_OWR_2" IDENTIFIED BY ICO_OWR_2 DEFAULT TABLESPACE "ICO_TBS_LARGE_OPR_DAT" TEMPORARY TABLESPACE "TEMP" PROFILE "S_APP_TECHNICAL_PROFILE";
GRANT "RESOURCE" TO "ICO_OWR_2";
GRANT "SELECT_CATALOG_ROLE" TO "ICO_OWR_2";
GRANT "EXECUTE_CATALOG_ROLE" TO "ICO_OWR_2";
GRANT "ICO_CONNECT_ROLE" TO "ICO_OWR_2";
GRANT "ICO_RESOURCE_ROLE" TO "ICO_OWR_2";
GRANT CREATE JOB TO "ICO_OWR_2";
GRANT ADVISOR TO "ICO_OWR_2";
GRANT DEBUG ANY PROCEDURE TO "ICO_OWR_2";
GRANT DEBUG CONNECT SESSION TO "ICO_OWR_2";
GRANT MERGE ANY VIEW TO "ICO_OWR_2";
GRANT CREATE MATERIALIZED VIEW TO "ICO_OWR_2";
GRANT CREATE DATABASE LINK TO "ICO_OWR_2";
GRANT SELECT ANY TABLE TO "ICO_OWR_2";
GRANT LOCK ANY TABLE TO "ICO_OWR_2";
GRANT DROP ANY TABLE TO "ICO_OWR_2";
GRANT ALTER ANY TABLE TO "ICO_OWR_2";
GRANT CREATE ANY TABLE TO "ICO_OWR_2";
GRANT UNLIMITED TABLESPACE TO "ICO_OWR_2";
-- directory permissions
GRANT READ ON DIRECTORY "DATA_PUMP_DIR" TO "ICO_OWR_2";
GRANT WRITE ON DIRECTORY "DATA_PUMP_DIR" TO "ICO_OWR_2";
GRANT WRITE ON DIRECTORY "DBDIR" TO "ICO_OWR_2" WITH GRANT OPTION;
GRANT READ ON DIRECTORY "DBDIR" TO "ICO_OWR_2" WITH GRANT OPTION;
GRANT EXECUTE ON DIRECTORY "DBDIR" TO "ICO_OWR_2" WITH GRANT OPTION;
-- for import and export operations
GRANT IMP_FULL_DATABASE TO "ICO_OWR_2";
GRANT EXP_FULL_DATABASE TO "ICO_OWR_2";

