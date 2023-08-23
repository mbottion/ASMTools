set lines 200
set pages 1000

select
   o.inst_id
  ,g.name
  ,o.operation
  ,o.state
  ,o.sofar
  ,o.est_work
  ,o.est_minutes
  ,o.error_code
from gv$asm_operation o
join gv$asm_diskgroup g on (     o.inst_id      = g.inst_id
                             and o.group_number = g.group_number )
order by
  o.operation
 ,o.inst_id
 ,o.group_number
 ,o.state
/

