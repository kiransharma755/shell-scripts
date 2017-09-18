set serveroutput on
declare 
snap_id number;
BEGIN
 snap_id:= dbms_workload_repository.create_snapshot();
 dbms_output.put_line('db_snapshot ' || snap_id);
END;
/
exit
