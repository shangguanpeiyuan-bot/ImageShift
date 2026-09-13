param([string]$Destination)
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not $Destination){$Destination=Join-Path $taskRoot 'artifacts\media-upgrade\runtime\ffmpeg'}
$taskManifest=Get-Content (Join-Path $PSScriptRoot 'native\ffmpeg-windows.json') -Raw | ConvertFrom-Json
$taskCache=Join-Path $taskRoot 'artifacts\media-upgrade\downloads'
New-Item -ItemType Directory -Force $taskCache,$Destination | Out-Null
$taskArchive=Join-Path $taskCache $taskManifest.download.name
if(-not (Test-Path -LiteralPath $taskArchive)) {
    Invoke-WebRequest $taskManifest.download.browser_download_url -OutFile $taskArchive
}
if(('sha256:'+(Get-FileHash $taskArchive -Algorithm SHA256).Hash.ToLower()) -ne $taskManifest.download.digest) {
    throw 'Native archive SHA256 mismatch. No binary installed.'
}
$taskExtract=Join-Path $taskCache 'ffmpeg-extracted'
if(-not (Test-Path -LiteralPath $taskExtract)) { Expand-Archive $taskArchive $taskExtract }
$taskBinary=Get-ChildItem $taskExtract -Recurse -Filter ffmpeg.exe | Select-Object -First 1
if(-not $taskBinary){throw 'Archive has no ffmpeg.exe'}
foreach($taskEntry in $taskManifest.files){
    $taskSource=Join-Path $taskBinary.DirectoryName $taskEntry.name
    if((Get-FileHash $taskSource -Algorithm SHA256).Hash.ToLower() -ne $taskEntry.sha256){throw "Binary mismatch: $($taskEntry.name)"}
    Copy-Item -LiteralPath $taskSource -Destination (Join-Path $Destination $taskEntry.name)
}
Copy-Item (Join-Path $taskRoot 'docs\third_party\ffmpeg-LGPL-3.0.txt') (Join-Path $Destination 'LICENSE.txt')
Write-Output "Verified FFmpeg runtime prepared: $Destination"
