select 
   failgroup
  ,failgroup_type
  ,mount_status
  ,mode_status
  ,COUNT(*) 
from 
  v$asm_disk 
group by 
   failgroup
  ,failgroup_type
  ,mount_status
  ,mode_status
order by
  failgroup;
