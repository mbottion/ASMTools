def d=/home/oracle/mbo/scaleDisks
set trimspool on
set term off
col outFile new_value outFile
select '&d/stat_' || to_char(sysdate,'yyyymmdd_hh24') || '.txt' outFile from dual
/
set term on
spool &outFile
set lines 200
set pages 100
col cell format a20
col group_name format a10
col typ format a2
col num format a4
break on cell skip 1
select
   cell
  ,group_name
  ,total_tb
  ,os_tb
  ,count(*)
from (
      select
         cell
        ,group_name
        ,num
        ,typ
        ,os_mb/1024/1024 os_tb
        ,total_mb/1024/1024 total_tb
      --  ,to_char(create_date,'dd/mm/yyyy') crea
      from (
            select 
               regexp_replace(name,'([^_]*)_([^_]*)_([^_]*)_(.*)','\4') cell
              ,regexp_replace(name,'([^_]*)_([^_]*)_([^_]*)_([^_]*)','\1') group_name
              ,regexp_replace(name,'([^_]*)_([^_]*)_([^_]*)_([^_]*)','\2') typ
              ,regexp_replace(name,'([^_]*)_([^_]*)_([^_]*)_([^_]*)','\3') num
              ,d.*
            from 
              v$asm_disk d
           )
      where
        cell like 'CDG%'
     )
group by
   cell
  ,group_name
  ,total_tb
  ,os_tb
order by
   substr(cell,15,2)
  ,group_name
/
spool off
