set serveroutput on
declare 
  n number ;
begin
  select 1 into n from v$instance where instance_name like '+ASM%' ;
  if (upper('&1') in ('USAGE','HELP','-?','-H'))
  then
    dbms_output.put_line('
+---------------------------------------------------------------------------------------
| Usage:
|    ASMMap.sql [detailLevel]
|   
|   Show contents of ASM Disk Groups (database directories or files)
|   and ACFS volumes. Sizes are shown intependently of redundancy (Real Sizes)
|   a given cases number.
|
|   Parameters :
|       detailLevel : If ''FILE'', shows all files (for DB part) - Default : DIR1 (first level directory)
|       
+---------------------------------------------------------------------------------------
       ');
   raise value_error ;
  end if ;
exception 
  when no_data_found then 
    dbms_output.put_line('This script must be ran against the ASM instance') ;
    raise ;
end ;
/

-- ------------------------------------------------------------------------
-- Parameters 
-- ------------------------------------------------------------------------
define detail_level="case when '&1' is null then 'DIR1' else upper('&1') end"

column break_dir new_value break_dir
column dir_len   new_value dir_len
set term off
select
   case &detail_level
     when 'DIR1' then 'on dir skip 1'
     else ''
   end break_dir
  ,case &detail_level
     when 'DIR1' then 'a40'
     else 'a90'
   end dir_len
from 
  dual ;
set term on

SET ECHO        OFF
SET FEEDBACK    6
SET HEADING     ON
SET LINESIZE    180
SET PAGESIZE    50000
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

COLUMN disk_group_name        FORMAT a15                  HEAD 'Disk Group'
COLUMN DIR                    FORMAT &dir_len             HEAD 'Directory'
COLUMN full_path              FORMAT a75                  HEAD 'ASM File Name / Volume Name / Device Name'
COLUMN system_created         FORMAT a8                   HEAD 'System|Created?'
COLUMN bytes                  FORMAT 9,999,999,999,999    HEAD 'Bytes'
COLUMN space                  FORMAT 9,999,999,999,999    HEAD 'Space'
COLUMN RealSize_GB            FORMAT 999G999D99           HEAD 'Size (GB)'
COLUMN space_GB               FORMAT 999G999D99           HEAD 'Occ. Space (GB)'
COLUMN File_count             FORMAT 999G999              HEAD 'Files Number'
COLUMN type                   FORMAT a25                  HEAD 'File Type'
COLUMN redundancy             FORMAT a12                  HEAD 'Redundancy'
COLUMN striped                FORMAT a8                   HEAD 'Striped'
COLUMN creation_date          FORMAT a20                  HEAD 'Creation Date'

BREAK ON report skip 1 ON disk_group_name skip 1 &break_dir

COMPUTE sum LABEL "Total dir"     OF RealSize_GB Space_GB ON dir
COMPUTE sum LABEL "Total DG"      OF RealSize_GB Space_GB ON disk_group_name
COMPUTE sum LABEL "Grand Total: " OF RealSize_GB Space_GB ON report

Prompt
Prompt ===============================================================
Prompt Disk Groups contents
Prompt ===============================================================
Prompt


select 
   disk_group_name
  ,case &detail_level
     when 'DIR1' then dir
     else             full_path
   end dir
  ,type
  ,count(*)                  File_count
  ,sum(bytes)/1024/1024/1024 RealSize_GB
  --,sum(space)/1024/1024/1024 Space_GB
from    (SELECT
            db_files.disk_group_name
          , NVL(db_files.type, '<DIRECTORY>')  || case when alias_num > 1 then ' (Alias)' else '' end type
          , regexp_replace(SYS_CONNECT_BY_PATH(db_files.alias_name, '/'),'^/([^/]*)/.*','\1') dir
          --, regexp_replace(SYS_CONNECT_BY_PATH(db_files.alias_name, '/'),'^/(.*)/([^/]*$)','\1') dir
          , SYS_CONNECT_BY_PATH(db_files.alias_name, '/') full_path
--          ,regexp_replace(SYS_CONNECT_BY_PATH(db_files.alias_name, '/')
--                         ,'^(/[^/]*/)(.*)(/[^/]*)(/[^/]*$)'
--                         ,'\1 ... \3\4'
--                         ) full_path /* Omitting intermediate levels */
          , case when alias_num > 1 then 0 else db_files.bytes end bytes
          , case when alias_num > 1 then 0 else db_files.space end space
          , db_files.creation_date
          , LPAD(db_files.system_created, 4) system_created
          ,alias_num
        FROM
            ( SELECT
                  g.name               disk_group_name
                , a.parent_index       pindex
                , a.name               alias_name
                , a.reference_index    rindex
                , a.system_created     system_created
                , f.bytes              bytes
                , f.space              space
                , f.type               type
                , TO_CHAR(f.creation_date, 'DD-MON-YYYY HH24:MI:SS')  creation_date
                , row_number() over (partition by group_number,file_number order by alias_index) alias_num
              FROM
                  v$asm_file f RIGHT OUTER JOIN v$asm_alias     a USING (group_number, file_number)
                                           JOIN v$asm_diskgroup g USING (group_number)
            ) db_files
        WHERE db_files.type IS NOT NULL
        START WITH (MOD(db_files.pindex, POWER(2, 24))) = 0
            CONNECT BY PRIOR db_files.rindex = db_files.pindex
        UNION
        SELECT
            volume_files.disk_group_name
          , NVL(volume_files.type, '<DIRECTORY>')  type
          ,regexp_replace(volume_files.volume_name,'^/([^/]*)/.*','\1')
          , volume_files.volume_name
          , volume_files.bytes
          , volume_files.space
          , volume_files.creation_date
          , null
          , null
        FROM
            ( SELECT 
                  g.name               disk_group_name
                , v.volume_name        volume_name
                , v.volume_device       volume_device
                , f.bytes              bytes
                , f.space              space
                , f.type               type
                , TO_CHAR(f.creation_date, 'DD-MON-YYYY HH24:MI:SS')  creation_date
              FROM
                  v$asm_file f RIGHT OUTER JOIN v$asm_volume    v USING (group_number, file_number)
                                           JOIN v$asm_diskgroup g USING (group_number)
            ) volume_files
        WHERE volume_files.type IS NOT NULL)
--where
--  disk_group_name = 'DATAC1'
group by
   disk_group_name
  ,case &detail_level
     when 'DIR1' then dir
     else        full_path
   end
  ,type
  ,dir
order by
   disk_group_name
  ,dir
  ,decode (type
          ,'DATAFILE'                  ,'010'
          ,'DATAFILE (Alias)'          ,'011'
          ,'TEMPFILE'                  ,'020'
          ,'TEMPFILE (Alias)'          ,'021'
          ,'ONLINELOG'                 ,'030'
          ,'ARCHIVELOG'                ,'040'
          ,'PASSWORD'                  ,'050'
          ,'PASSWORD (Alias)'          ,'051'
          ,'DATAGUARDCONFIG'           ,'060'
          ,'DATAGUARDCONFIG (Alias)'   ,'061'
          ,'900'||type)
/

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
  v$asm_diskgroup;
