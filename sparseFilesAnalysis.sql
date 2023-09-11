

Prompt
Prompt =======================================================================================
Prompt .
Prompt .         Sparse disk group usage and per sparse database virtual and
Prompt .   physical allocation.
Prompt .
Prompt =======================================================================================
Prompt

set lines 200
set tab off
set trimspool on


Prompt
Prompt ===============================================================
Prompt Sparse disk group USAGE (Physical space)
Prompt ===============================================================
Prompt

col phys_TB format 990D999 heading "Physical (TB)"
col all_TB  format 990D999 heading "Allocated (TB)"
col pct     format a20     heading "Free %"
select
   TOTAL_MAT_MB/1024/1024/3     phys_TB
  ,ALLOCATED_MAT_MB/1024/1024/3 all_TB
  ,to_char( ((TOTAL_MAT_MB-ALLOCATED_MAT_MB)/TOTAL_MAT_MB)*100,'9990D99' ) || ' %' as pct
from
  V$ASM_DISKGROUP_SPARSE ;


Prompt
Prompt ===============================================================
Prompt Sparse disk group USAGE (Physical space) per cloned database
Prompt ===============================================================
Prompt

col clone_type           format a20                heading "Clone Type"
col db_unique_name       format a25                heading "Database"
col clone_suffix         format a10                heading "Suffix"
col Virtual_Size_TB      format 999D999            heading "Virt Size (TB)"
col Allocated_Size_TB    format 999D999            heading "Allocated (TB)"
col Used_Size_TB         format 999D999            heading "Used (TB)"
col Number_of_Datafiles  format 999G999            heading "# datafiles"

break on clone_type skip 2 on db_unique_name skip 1 on report

compute sum of Virtual_Size_TB Allocated_Size_TB Used_Size_TB on db_unique_name
compute sum of Virtual_Size_TB Allocated_Size_TB Used_Size_TB on report

set timing on

Select 
   case clone_type
     when 'STBY' then 'Sparse standby'
     when 'SM'   then 'Test master'
     when 'SN'   then 'Snapshot'
     else clone_type
   end clone_type
  ,db_unique_name
  ,clone_suffix
  ,sum(FILSIZ_KFFIL_SPARSE    / 1024 / 1024 / 1024 / 1024)     as Virtual_Size_TB
  ,sum(ALLOCMAT_KFFIL_SPARSE  / 1024 / 1024 / 1024 / 1024) / 3 as Allocated_Size_TB
  ,sum(USEDMAT_KFFIL_SPARSE   / 1024 / 1024 / 1024 / 1024) / 3 as Used_Size_TB
  ,sum(1)                                                      as Number_of_Datafiles
From 
  (select
      regexp_replace(fname_kffil_sparse,'^(+[^/]*)/(+[^/]*)/.*$','\2')          db_unique_name
     ,case 
        when upper(fname_kffil_sparse) like '%TEMP%' then 'SN'
        else regexp_replace(fname_kffil_sparse,'^(+[^/]*)/(+[^/]*)/.*_(STBY|SM|SN)([^.]*)\..*$','\3') 
      end Clone_type
     ,case 
        when upper(fname_kffil_sparse) like '%TEMP%' then 'TEMPFILES'
        else regexp_replace(fname_kffil_sparse,'^(+[^/]*)/(+[^/]*)/.*_(STBY|SM|SN)([^.]*)\..*$','\4') 
      end clone_suffix
     ,FILSIZ_KFFIL_SPARSE
     ,ALLOCMAT_KFFIL_SPARSE
     ,USEDMAT_KFFIL_SPARSE
   from
      x$kffil_sparse
  where 
    fname_kffil_sparse like '+SPR%')
group by
   clone_type
  ,db_unique_name
  ,clone_suffix
order by
   case clone_type
     when 'STBY' then 1
     when 'SM'   then 3
     when 'SN'   then 2
     else 4
   end 
  ,db_unique_name
  ,clone_suffix
/
