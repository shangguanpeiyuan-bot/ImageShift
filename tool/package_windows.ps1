param(
    [Parameter(Mandatory=$true)][string]$IsccPath,
    [Parameter(Mandatory=$true)][string]$CrtDirectory,
    [Parameter(Mandatory=$true)][string]$ArtifactLabel,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$release=Join-Path $projectRoot 'build\windows\x64\runner\Release'
if($ArtifactLabel -notmatch '^[a-zA-Z0-9._-]+$'){throw 'Invalid artifact label'}
$dist=[IO.Path]::GetFullPath($OutputDirectory)
if(-not $dist.StartsWith((Join-Path $projectRoot 'artifacts') + '\',[StringComparison]::OrdinalIgnoreCase)){throw 'Packaging must use a project artifacts directory'}
$compiler=(Resolve-Path -LiteralPath $IsccPath).ProviderPath
$runtime=(Resolve-Path -LiteralPath $CrtDirectory).ProviderPath
foreach($required in @('imageshift.exe','flutter_windows.dll','data\app.so')) {
    if(-not (Test-Path -LiteralPath (Join-Path $release $required))) {throw "Missing Release file: $required"}
}
foreach($required in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
    if(-not (Test-Path -LiteralPath (Join-Path $runtime $required))) {throw "Missing redistributable runtime: $required"}
}
foreach($dll in Get-ChildItem -LiteralPath $runtime -Filter '*.dll') {
    $destination=Join-Path $release $dll.Name
    if((Test-Path -LiteralPath $destination) -and
       ((Get-FileHash -LiteralPath $dll.FullName).Hash -eq (Get-FileHash -LiteralPath $destination).Hash)){continue}
    Copy-Item -LiteralPath $dll.FullName -Destination $destination
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination (Join-Path $release 'LICENSE.txt')
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$installer=Join-Path $dist "ImageShift-$ArtifactLabel-Windows-Setup.exe"
$archive=Join-Path $dist "ImageShift-$ArtifactLabel-Windows-x64.zip"
if((Test-Path -LiteralPath $installer) -or (Test-Path -LiteralPath $archive)){throw 'Artifact exists; choose a fresh label/directory instead of overwriting'}
& $compiler "/DAppSource=$release" "/DDistDir=$dist" "/DArtifactLabel=$ArtifactLabel" (Join-Path $PSScriptRoot 'imageshift.iss')
if($LASTEXITCODE -ne 0){throw 'Installer compile failed'}
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $archive
Get-FileHash -LiteralPath $installer,$archive -Algorithm SHA256
