set lines 1000 pages 1000 tab off trimspool on
define prompt = "[ not connected ] SQL> "
column prompt new_value prompt
set termout off
select '[ '||lower(user) || ' @ ' || substr(global_name,1,decode(instr(global_name,'.'),0,length(global_name),instr(global_name,'.')-1)) || ' ]:' || chr(10) || 'SQL> '  prompt from global_name;
set termout on
set sqlprompt "&prompt"
