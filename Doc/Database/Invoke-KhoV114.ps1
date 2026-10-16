param([switch]$Apply,[switch]$Rollback,[string]$BackupDirectory)
$ErrorActionPreference='Stop'
$scriptRoot=if($PSScriptRoot){$PSScriptRoot}else{Join-Path (Get-Location).Path 'Doc/Database'}
$repoRoot=Split-Path (Split-Path $scriptRoot -Parent) -Parent
$vroot=Join-Path $scriptRoot 'V114'
$settings=Get-Content (Join-Path $repoRoot 'QuanLyPhongMach/appsettings.json') -Raw|ConvertFrom-Json
$connectionText=$settings.ConnectionStrings.QLPM
foreach($name in @('appsettings.Development.json','appsettings.local.json')){
 $p=Join-Path $repoRoot ('QuanLyPhongMach/'+$name)
 if(Test-Path -LiteralPath $p){$o=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json;if($o.ConnectionStrings.QLPM){$connectionText=$o.ConnectionStrings.QLPM}}
}
$connectionText=[regex]::Replace($connectionText,'(?i)(^|;)\s*Command Timeout\s*=\s*[^;]*','')
$connection=New-Object System.Data.SqlClient.SqlConnection($connectionText)
$transaction=$null
function Scalar([string]$sql){
 $c=$connection.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$sql
 if($transaction){$c.Transaction=$transaction}
 try{return $c.ExecuteScalar()}finally{$c.Dispose()}
}
function Execute([string]$sql){
 $c=$connection.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$sql
 if($transaction){$c.Transaction=$transaction}
 try{$null=$c.ExecuteNonQuery()}finally{$c.Dispose()}
}
function RunSql([string]$path){
 $sql=Get-Content -LiteralPath $path -Raw -Encoding utf8
 foreach($batch in [regex]::Split($sql,'(?im)^\s*GO\s*(?:--[^\r\n]*)?$')){if($batch.Trim()){Execute $batch}}
}
function Hash([string]$text){
 $s=[Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-','')}finally{$s.Dispose()}
}
function ModuleHash([string]$text){return Hash ($text.Replace([string][char]13+[char]10,[string][char]10).Trim())}
function DataHash([string]$sql){return Hash ([string](Scalar ('SELECT ('+$sql+' FOR JSON PATH,INCLUDE_NULL_VALUES)')))}
function TableHash([string]$table){
 $order=if($table -eq 'QL_Kho_SoChungTu'){'IDCSKCB,MaLoai'}elseif($table -in @('QL_Kho_ChungTu','QL_Kho_ChungTu_CT')){'LoaiChungTu,ID'}else{'ID'}
 return DataHash ('SELECT * FROM dbo.'+$table+' ORDER BY '+$order)
}
function GuardModules {
 $expected=Get-Content (Join-Path $vroot 'expected_modules.json') -Raw -Encoding utf8|ConvertFrom-Json
 foreach($m in $expected){
  $actual=[string](Scalar ("SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo."+$m.name+"'))"))
  if((ModuleHash $actual) -ne (ModuleHash $m.definition)){throw ('Module changed since reviewed baseline: '+$m.name)}
 }
}
function GuardSchema {
 $expected=Get-Content (Join-Path $vroot 'schema_baseline.json') -Raw -Encoding utf8|ConvertFrom-Json
 foreach($p in $expected.PSObject.Properties){
  $actual=[string](Scalar $p.Value.Query)
  if((Hash $actual) -ne $p.Value.Hash){throw ('Warehouse metadata changed since review: '+$p.Name)}
 }
}
function GuardRollback {
 RunSql (Join-Path $scriptRoot '62_kho_kiem_tra_v114.sql')
 $deployed=Get-Content (Join-Path $vroot 'deployed_modules.json') -Raw -Encoding utf8|ConvertFrom-Json
 foreach($m in $deployed){
  $actual=[string](Scalar ("SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo."+$m.name+"'))"))
  if((ModuleHash $actual) -ne (ModuleHash $m.definition)){throw ('Module changed after cutover; review reverse migration: '+$m.name)}
 }
 $names=@($deployed|ForEach-Object{"N'"+$_.name.Replace("'","''")+"'"}) -join ','
 $extra=[long](Scalar ("SELECT COUNT(*) FROM sys.sql_expression_dependencies D WHERE D.referenced_id IN(OBJECT_ID(N'dbo.QL_Kho_ChungTu'),OBJECT_ID(N'dbo.QL_Kho_ChungTu_CT')) AND OBJECT_NAME(D.referencing_id) NOT IN("+$names+")"))
 if($extra -ne 0){throw 'Additional canonical dependency; update reverse migration before rollback.'}
}
$mapping=Get-Content (Join-Path $vroot 'mapping.json') -Raw -Encoding utf8|ConvertFrom-Json
$oldTables=@('QL_Kho_Nhap','QL_Kho_Nhap_CT','QL_Kho_Xuat','QL_Kho_Xuat_CT','QL_Kho_Hoan','QL_Kho_Hoan_CT','QL_Kho_DieuChinh','QL_Kho_DieuChinh_CT','QL_Kho_KiemKe','QL_Kho_KiemKe_CT','QL_Kho_XuatKhac','QL_Kho_XuatKhac_CT','QL_Kho_KhoaLo','QL_Kho_SoChungTu')
$preserved=@('DM_Kho','QL_Kho_LoThuoc','QL_Kho_GiaoDich')
$before=[ordered]@{};$after=[ordered]@{}
$connection.Open()
try{
 if((Scalar "SELECT CONCAT(@@SERVERNAME,N'/',DB_NAME())") -ne 'Hieu/QLPM'){throw 'Refuse target other than Hieu/QLPM.'}
 $version=[int](Scalar 'SELECT MAX(VersionNo) FROM dbo.QLPM_SchemaVersion')
 if($Rollback -and !$Apply){throw 'Rollback requires explicit -Apply.'}
 if(!$Rollback -and $version -eq 114){RunSql (Join-Path $scriptRoot '62_kho_kiem_tra_v114.sql');Write-Output 'Hieu/QLPM already at v114; no writes.';return}
 if((!$Rollback -and $version -ne 113) -or ($Rollback -and $version -ne 114)){throw 'Unexpected schema version; review target before proceeding.'}
 if(!$Rollback){GuardModules;GuardSchema}else{GuardRollback}
 $targetTables=if($Rollback){@('QL_Kho_ChungTu','QL_Kho_ChungTu_CT')+$preserved}else{$oldTables+$preserved}
 foreach($t in $targetTables){$before[$t]=[ordered]@{Count=[long](Scalar ('SELECT COUNT_BIG(*) FROM dbo.'+$t));Hash=TableHash $t}}
 if(!$Apply){[ordered]@{Target='Hieu/QLPM';Version=$version;Mode='ReadOnly';Rows=$before}|ConvertTo-Json -Depth 6;return}

 $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
 $folder=Join-Path $scriptRoot ('ChangeLogs/KhoV114_'+$(if($Rollback){'Rollback_'}else{''})+$stamp)
 $null=New-Item -ItemType Directory -Path $folder
 Copy-Item -LiteralPath $vroot -Destination (Join-Path $folder 'V114') -Recurse
 foreach($name in @('59_kho_gop_chung_tu_v114.sql','60_kho_sto_v114.sql','61_kho_chot_schema_v114.sql','62_kho_kiem_tra_v114.sql','Invoke-KhoV114.ps1')){Copy-Item -LiteralPath (Join-Path $scriptRoot $name) -Destination $folder}
 if(!$BackupDirectory){$BackupDirectory=[string](Scalar "SELECT CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'))")}
 if(!$BackupDirectory){throw 'SQL Server backup directory unavailable.'}
 $backup=Join-Path $BackupDirectory ('QLPM_before_kho_v114_'+$(if($Rollback){'rollback_'}else{''})+$stamp+'.bak')
 $escaped=$backup.Replace("'","''")
 Execute ("BACKUP DATABASE [QLPM] TO DISK=N'"+$escaped+"' WITH COPY_ONLY,CHECKSUM,INIT")
 Execute ("RESTORE VERIFYONLY FROM DISK=N'"+$escaped+"' WITH CHECKSUM")
 Write-Output 'Native COPY_ONLY backup verified. Starting atomic warehouse cutover.'
 $manifest=[ordered]@{Target='Hieu/QLPM';Backup=$backup;BackupVerified=$true;Rollback=[bool]$Rollback;Before=$before;Applied=$false;BusinessTestsRun=0;Sources=@{}}
 foreach($f in Get-ChildItem -LiteralPath $folder -File){$manifest.Sources[$f.Name]=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash}
 $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $folder 'manifest.json') -Encoding utf8
 $transaction=$connection.BeginTransaction()
 try{
  Execute 'SET XACT_ABORT ON; SET LOCK_TIMEOUT 10000;'
  foreach($t in $targetTables){$null=Scalar ('SELECT COUNT_BIG(*) FROM dbo.'+$t+' WITH(TABLOCKX,HOLDLOCK)')}
  # Re-read after acquiring all locks: data can legitimately change before cutover.
  foreach($t in $targetTables){$before[$t]=[ordered]@{Count=[long](Scalar ('SELECT COUNT_BIG(*) FROM dbo.'+$t));Hash=TableHash $t}}
  if(!$Rollback){
   GuardModules;GuardSchema
   foreach($t in $oldTables|Select-Object -Skip 8){if($before[$t].Count -ne 0){throw ('Unused table is no longer empty: '+$t)}}
   # Reject additional schema dependencies/permissions rather than silently discarding them.
   $outside=[long](Scalar "SELECT COUNT(*) FROM sys.foreign_keys WHERE OBJECT_NAME(referenced_object_id) LIKE 'QL_Kho[_]%' AND OBJECT_NAME(parent_object_id) NOT LIKE 'QL_Kho[_]%'")
   if($outside -ne 0){throw 'External warehouse FK changed; update migration first.'}
   $perm=[long](Scalar "SELECT COUNT(*) FROM sys.database_permissions WHERE OBJECT_NAME(major_id) LIKE 'QL_Kho[_]%' OR OBJECT_NAME(major_id) LIKE 'STO_QL_Kho%'")
   if($perm -ne 0){throw 'Explicit warehouse grants require a reviewed mapping.'}
   RunSql (Join-Path $scriptRoot '59_kho_gop_chung_tu_v114.sql')
   foreach($p in $mapping.specs.PSObject.Properties){
    $t=$p.Name;$spec=$p.Value;$mp=$mapping.mapping.$t
    $cols=@($mp.PSObject.Properties|ForEach-Object{'['+$_.Value+'] AS ['+$_.Name+']'}) -join ','
    $actual=DataHash ('SELECT '+$cols+' FROM dbo.'+$spec[1]+" WHERE LoaiChungTu='"+$spec[0]+"' ORDER BY ID")
    if($actual -ne $before[$t].Hash){throw ('Exact JSON/hash copy mismatch: '+$t)}
   }
   RunSql (Join-Path $scriptRoot '60_kho_sto_v114.sql')
   RunSql (Join-Path $scriptRoot '61_kho_chot_schema_v114.sql')
   foreach($p in $mapping.affected){Execute ("EXEC sys.sp_refreshsqlmodule N'dbo."+$p+"'")}
   RunSql (Join-Path $scriptRoot '62_kho_kiem_tra_v114.sql')
   Execute "INSERT dbo.QLPM_SchemaVersion(VersionNo,TenMigration,BranchName) VALUES(114,N'warehouse-canonical-documents-v114',N'Hieu_12/10_1')"
  }else{
   GuardRollback
   # Preserve current lots/ledger and copy ALL canonical documents, including after cutover.
   Execute 'DROP TRIGGER IF EXISTS dbo.TR_QL_Kho_ChungTu_CT_GiaoDich; DROP TRIGGER IF EXISTS dbo.TR_QL_Kho_ChungTu_HuyNhap_GiaoDich;'
   RunSql (Join-Path $vroot 'rollback_create.sql')
   RunSql (Join-Path $vroot 'rollback_copy.sql')
   foreach($p in $mapping.specs.PSObject.Properties){
    $t=$p.Name;$spec=$p.Value;$mp=$mapping.mapping.$t
    $cols=@($mp.PSObject.Properties|ForEach-Object{'['+$_.Value+'] AS ['+$_.Name+']'}) -join ','
    $expected=DataHash ('SELECT '+$cols+' FROM dbo.'+$spec[1]+" WHERE LoaiChungTu='"+$spec[0]+"' ORDER BY ID")
    if((DataHash ('SELECT * FROM dbo.'+$t+' ORDER BY ID')) -ne $expected){throw ('Reverse copy mismatch: '+$t)}
    $seq='SEQ_Kho_'+$spec[0]+$(if($spec[3]){'_CT'}else{''})
    $high=[long](Scalar ("SELECT CONVERT(bigint,current_value) FROM sys.sequences WHERE name='"+$seq+"'"))
    Execute ("DBCC CHECKIDENT(N'dbo."+$t+"', RESEED, "+$high+") WITH NO_INFOMSGS")
   }
   RunSql (Join-Path $vroot 'rollback_constraints.sql')
   RunSql (Join-Path $vroot 'rollback_modules.sql')
   Execute 'ALTER TABLE dbo.QL_Kho_ChungTu_CT DROP CONSTRAINT FK_QL_Kho_ChungTu_CT_Goc; DROP TABLE dbo.QL_Kho_ChungTu_CT; DROP TABLE dbo.QL_Kho_ChungTu;'
   foreach($family in @('NHAP','CAP_PHAT','HOAN','DIEU_CHINH')){Execute ('DROP SEQUENCE dbo.SEQ_Kho_'+$family+'; DROP SEQUENCE dbo.SEQ_Kho_'+$family+'_CT;')}
   Execute 'DELETE FROM dbo.QLPM_SchemaVersion WHERE VersionNo=114;'
  }
  foreach($t in $preserved){
   $after[$t]=[ordered]@{Count=[long](Scalar ('SELECT COUNT_BIG(*) FROM dbo.'+$t));Hash=DataHash ('SELECT * FROM dbo.'+$t+' ORDER BY ID')}
   if($after[$t].Hash -ne $before[$t].Hash -or $after[$t].Count -ne $before[$t].Count){throw ('Preserved table changed: '+$t)}
  }
  $transaction.Commit()
 }catch{try{$transaction.Rollback()}catch{};throw}finally{$transaction.Dispose();$transaction=$null}
 $manifest.Applied=$true;$manifest.Before=$before;$manifest.AfterPreserved=$after
 $manifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $folder 'manifest.json') -Encoding utf8
 Write-Output ('KHO_V114_'+$(if($Rollback){'ROLLBACK'}else{'APPLY'})+'_OK; manifest: '+(Join-Path $folder 'manifest.json'))
}finally{$connection.Close()}
