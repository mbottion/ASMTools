set lines 200
set pages 1000

col prog format a30 heading "Progress"
col est_work format 999G999G999
col sofar    format 999G999G999
col est_minutes format 999G999


select
   o.inst_id
  ,g.name
  ,o.operation
  ,power
  ,o.state
  ,o.sofar
  ,o.est_work
  ,o.est_minutes
  ,o.error_code
  ,case
    when nvl(o.est_work,0) != 0 then 'In Progress : ' || to_char( ( sofar / est_work ) * 100 , '999D99') || ' %'
    else null
   end prog
from gv$asm_operation o
join gv$asm_diskgroup g on (     o.inst_id      = g.inst_id
                             and o.group_number = g.group_number )
order by
  o.operation
 ,o.inst_id
 ,o.group_number
 ,o.state
/
