

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

clear columns

column name                    format a15 heading "DG Name"
column real_size_tb            format 999 heading "Size (TB)"
column state                   format a10 heading "State"
column offline_disks           format 999 heading "Offline Disks"
column compatibility           format a15 heading "Compatibility"
column database_compatibility  format a15 heading "DB Compat."
column voting_files            format a10 heading "Vot. Files?"


Prompt
Prompt ===============================================================
Prompt Disk Groups state and size
Prompt ===============================================================
Prompt

select 
   name
  ,round(total_mb/1024/1024/case type when 'HIGH' then 3 when 'NORMAL' then 2 else 1 end) real_size_TB
  ,state
  ,offline_disks
  ,compatibility
  ,database_compatibility
  ,voting_files
from 
  v$asm_diskgroup
where
  name like 'SPR%' ;

column free_TB format 990D99
column total_TB format 990D99
column usable_file_TB format 990D99
column percentage_free format a20
SELECT 
   name
  ,(free_mb/1024/1024) /case type when 'HIGH' then 3 when 'NORMAL' then 2 else 1 end free_TB
  ,(total_mb/1024/1024) /case type when 'HIGH' then 3 when 'NORMAL' then 2 else 1 end total_TB
  ,(usable_file_mb/1024/1024)  usable_file_TB
  ,to_char(free_mb/total_mb*100,'990D99') || ' %' as percentage_free 
FROM 
  v$asm_diskgroup
where
  name like 'SPR%';


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


set timing on
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
col ct_code              format 999G999            

break on clone_type skip 2 on db_unique_name skip 1 on report

compute sum of Virtual_Size_TB Allocated_Size_TB Used_Size_TB on db_unique_name
compute sum of Virtual_Size_TB Allocated_Size_TB Used_Size_TB on report

select
   clone_type
  ,db_unique_name
  ,Virtual_Size_TB
  ,Allocated_Size_TB
  ,Used_Size_TB
  ,Number_of_Datafiles
from (Select 
         case clone_type
           when 'STBY' then 'Sparse standby'
           when 'SM'   then 'Test master'
           when 'SN'   then 'Snapshot'
           else clone_type
         end clone_type
        ,clone_type ct_code
        ,db_unique_name
        ,clone_suffix
        ,sum(FILSIZ_KFFIL_SPARSE    / 1024 / 1024 / 1024 / 1024)     as Virtual_Size_TB
        ,sum(ALLOCMAT_KFFIL_SPARSE  / 1024 / 1024 / 1024 / 1024) / 3 as Allocated_Size_TB
        ,sum(USEDMAT_KFFIL_SPARSE   / 1024 / 1024 / 1024 / 1024) / 3 as Used_Size_TB
        ,sum(1)                                                      as Number_of_Datafiles
      From (select
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
            where fname_kffil_sparse like '+SPR%')
       group by
         clone_type
        ,db_unique_name
        ,clone_suffix)
order by
   decode( ct_code
         ,'STBY' , 1
         ,'SM'   , 3
         ,'SN'   , 2
         , 4 )
  ,db_unique_name
  ,clone_suffix
/
