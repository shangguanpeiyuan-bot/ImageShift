param(
    [Parameter(Mandatory=$true)][string]$IsccPath,
    [Parameter(Mandatory=$true)][string]$CrtDirectory
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$release=Join-Path $projectRoot 'build\windows\x64\runner\Release'
$dist=Join-Path $projectRoot 'artifacts\phase-d\dist'
$compiler=(Resolve-Path -LiteralPath $IsccPath).ProviderPath
$runtime=(Resolve-Path -LiteralPath $CrtDirectory).ProviderPath
foreach($required in @('imageshift.exe','flutter_windows.dll','data\app.so')) {
    if(-not (Test-Path -LiteralPath (Join-Path $release $required))) {throw "Missing Release file: $required"}
}
foreach($required in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
    if(-not (Test-Path -LiteralPath (Join-Path $runtime $required))) {throw "Missing redistributable runtime: $required"}
}
Get-ChildItem -LiteralPath $runtime -Filter '*.dll' | Copy-Item -Destination $release
New-Item -ItemType Directory -Force -Path $dist | Out-Null
& $compiler "/DAppSource=$release" "/DDistDir=$dist" (Join-Path $PSScriptRoot 'imageshift.iss')
if($LASTEXITCODE -ne 0){throw 'Installer compile failed'}
$archive=Join-Path $dist 'ImageShift-v1.0.0-Windows-x64.zip'
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $archive -Force
Get-FileHash -LiteralPath (Join-Path $dist 'ImageShift-v1.0.0-Windows-Setup.exe'),$archive -Algorithm SHA256
