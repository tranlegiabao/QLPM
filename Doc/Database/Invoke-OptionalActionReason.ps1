param([switch]$Apply)
$ErrorActionPreference='Stop'
$scriptRoot=if($PSScriptRoot){$PSScriptRoot}else{Join-Path (Get-Location).Path 'Doc\Database'}
$repoRoot=Split-Path (Split-Path $scriptRoot -Parent) -Parent
$source=Join-Path $scriptRoot '58_thao_tac_khong_bat_buoc_ly_do.sql'
$expectedSourceHash='BEC811A47A61AEC136895DAB464D6397E7728E2337DB38505D984F793C048C71'
$expected=@{
 'STO_QL_Kho_XuatKhac_Luu'=@{Before='F0865D2FDC3C2AA01BB5F3A27C2E0F983C8168C3651B0B4CFC1FEB0187BB0A19';After='5A8B144EFB444D32D09F0FB66C24FE527371120D041CC726ABD832BC6FD5851B'}
 'STO_QL_Kho_XuatKhac_Huy'=@{Before='BE289542612EEC3CEFD1F665F90F89DFA8413043DD14F6FC4C03BE9A39847521';After='AF7FDBC8F3F97695CCCF03D055E4B6512D06142F0243614F531F3590A2324387'}
 'STO_QL_Kho_KhoaLo_Luu'=@{Before='1B54FCCFDB1214A7D76BA0B02C27C64F43CE0C462B13500329AF7BF433B2096E';After='4492B4AA58CBA5D4CCC51FAE37B7780A9F0B01FC8EA88C5CB88F731BCA8BB4B9'}
 'STO_QL_Kho_KiemKe_HuyNhap'=@{Before='22F9F21C9601701DA7599D686ED27A04CB213465765396AA95313EE3C6B9489D';After='6C37DE1022D482D2FF5D7E411FAB0487B3583129AD9DF57B092850F881236798'}
 'STO_QL_Kho_DieuChinh_Luu'=@{Before='CAB763004CB6BDD8625E066E8646ABB810FFB80D45496B390115AB384482F51D';After='03E605E2555208C932B06950BD7E5464BC45B8142D7D9E90AC4F34780AC5B5AF'}
 'STO_QL_Kho_Nhap_Huy'=@{Before='2B4DF69E78D73ED314F2B768A12BC10D906FDB5638F48E2FBF58BC6F8EE53309';After='4E0BE74D6E685874D6089C53CD4CC3F4505CF0BD7839729D9D3B45C6EF5EEA35'}
 'STO_QL_ThuNgan_HuyChungTu'=@{Before='CBACD9066139EA82480E9D5FE7FB0E462DC1CC29FFF79CDCFF7888F7BBC4C014';After='F9D8C726D428065D16208709676DE7A1B66C164F65F2DBC0723881AEA037C978'}
 'STO_QL_ThuNgan_HoanTien'=@{Before='95C8CFFF9784C0F9E7515B7AA517A51A47BB0FB8925DA787CA119BB7F533C1F6';After='47105E91E11EA70E8F356F8D36C12087998A1D85F02A1BBC676BFCC33BE3CB28'}
 'STO_QL_Kho_Xuat_Hoan'=@{Before='CCBBA1C52F27FD1DABC6BB133EA5AECB701DB6052C615FF0441A8B94F53F4C57';After='CD68536C2622C50F51E8E08AB7FCFB289918FA131E1DE241CFD5AA56CE45639B'}
}
$settings=Get-Content (Join-Path $repoRoot 'QuanLyPhongMach\appsettings.json') -Raw | ConvertFrom-Json
$connectionText=$settings.ConnectionStrings.QLPM
foreach($name in @('appsettings.Development.json','appsettings.local.json')){
 $path=Join-Path $repoRoot ('QuanLyPhongMach\'+$name)
 if(Test-Path -LiteralPath $path){
  $override=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
  if($override.ConnectionStrings.QLPM){$connectionText=$override.ConnectionStrings.QLPM}
 }
}
$connectionText=[regex]::Replace($connectionText,'(?i)(^|;)\s*Command Timeout\s*=\s*[^;]*','')
$connection=New-Object System.Data.SqlClient.SqlConnection($connectionText)
$transaction=$null
function Scalar([string]$sql){
 $command=$connection.CreateCommand();$command.CommandTimeout=60;$command.CommandText=$sql
 if($transaction){$command.Transaction=$transaction}
 try{return $command.ExecuteScalar()}finally{$command.Dispose()}
}
function Execute([string]$sql){
 $command=$connection.CreateCommand();$command.CommandTimeout=60;$command.CommandText=$sql
 if($transaction){$command.Transaction=$transaction}
 try{$null=$command.ExecuteNonQuery()}finally{$command.Dispose()}
}
function ProcedureHash([string]$definition){
 $canonical=$definition.Replace([string][char]13+[char]10,[string][char]10).Trim()
 $canonical=[regex]::Replace($canonical,'(?i)^CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE','CREATE OR ALTER PROCEDURE')
 $hash=[System.Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))).Replace('-','')}finally{$hash.Dispose()}
}
$connection.Open()
try{
 $server=[string](Scalar 'SELECT @@SERVERNAME');$database=[string](Scalar 'SELECT DB_NAME()')
 if($server -ne 'Hieu' -or $database -ne 'QLPM'){throw 'Refuse target other than Hieu/QLPM.'}
 if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $expectedSourceHash){throw 'Reviewed SQL source changed.'}
 $old=[ordered]@{}
 foreach($name in $expected.Keys|Sort-Object){
  $definition=[string](Scalar "SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.$name',N'P'))")
  if(!$definition){throw "Procedure missing: $name"}
  $hash=ProcedureHash $definition
  if($hash -ne $expected[$name].Before -and $hash -ne $expected[$name].After){throw "Procedure changed since inspection: $name"}
  $old[$name]=@{Definition=$definition;
   Ansi=[int](Scalar "SELECT uses_ansi_nulls FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.$name')");
   Quoted=[int](Scalar "SELECT uses_quoted_identifier FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.$name')")}
 }
 if(!$Apply){[ordered]@{Server=$server;Database=$database;Mode='MetadataOnly';Procedures=@($old.Keys)}|ConvertTo-Json;return}

 $folder=Join-Path $repoRoot ('Doc\Database\ChangeLogs\OptionalActionReason_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
 $null=New-Item -ItemType Directory -Path $folder
 $rollback=@('USE [QLPM];','GO')
 foreach($name in $old.Keys){
  $ansi=if($old[$name].Ansi){'ON'}else{'OFF'};$quoted=if($old[$name].Quoted){'ON'}else{'OFF'}
  $definition=[regex]::Replace($old[$name].Definition,'(?im)^\s*(?:CREATE(?:\s+OR\s+ALTER)?|ALTER)\s+PROCEDURE\b','CREATE OR ALTER PROCEDURE')
  $rollback+=@("SET ANSI_NULLS $ansi; SET QUOTED_IDENTIFIER $quoted;",'GO',$definition,'GO')
 }
 $rollback -join [Environment]::NewLine|Set-Content -LiteralPath (Join-Path $folder 'before.sql') -Encoding utf8

 $transaction=$connection.BeginTransaction()
 try{
  $sql=Get-Content -LiteralPath $source -Raw -Encoding utf8
  foreach($batch in [regex]::Split($sql,'(?im)^\s*GO\s*(?:--[^\r\n]*)?$')){if($batch.Trim()){Execute $batch}}
  foreach($name in $expected.Keys){
   $definition=[string](Scalar "SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.$name',N'P'))")
   if((ProcedureHash $definition) -ne $expected[$name].After){throw "Unexpected deployed definition: $name"}
  }
  $transaction.Commit()
 }catch{try{$transaction.Rollback()}catch{};throw}finally{$transaction.Dispose();$transaction=$null}
 $manifest=[ordered]@{Server=$server;Database=$database;SourceSha256=$expectedSourceHash;Procedures=@($old.Keys);
  Rollback=(Join-Path $folder 'before.sql');TablesChanged=0;OperatingDataWritten=0;BusinessTestsRun=0;Applied=$true}
 $manifest|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $folder 'manifest.json') -Encoding utf8
 $manifest|ConvertTo-Json -Depth 5
}finally{$connection.Close()}

