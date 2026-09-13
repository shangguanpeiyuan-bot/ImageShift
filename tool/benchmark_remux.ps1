param([string]$Runtime)
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not $Runtime){$Runtime=Join-Path $taskRoot 'artifacts/media-upgrade/runtime/ffmpeg'}
$taskFfmpeg=(Resolve-Path (Join-Path $Runtime 'ffmpeg.exe')).Path
$taskProbe=(Resolve-Path (Join-Path $Runtime 'ffprobe.exe')).Path
$taskFolder=Join-Path $taskRoot 'artifacts/media-upgrade/large-video'
New-Item -ItemType Directory -Force $taskFolder | Out-Null
$taskFree=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($taskFolder)).AvailableFreeSpace
if($taskFree -lt 4GB){throw 'Need 4 GiB free for generated benchmark and output.'}
$taskSeed=Join-Path $taskFolder 'seed.mkv'
$taskSource=Join-Path $taskFolder 'source-1GiB.mkv'
if(-not(Test-Path $taskSeed)) {
    & $taskFfmpeg -v error -n -f lavfi -i 'testsrc2=s=640x480:r=30,noise=alls=100:allf=t+u:all_seed=1' -t 2 -c:v libopenh264 -b:v 30000k $taskSeed
    if($LASTEXITCODE){throw 'Seed generation failed'}
}
if(-not(Test-Path $taskSource)) {
    & $taskFfmpeg -v error -n -stream_loop 10000 -i $taskSeed -map 0 -c copy -fs 1073741824 $taskSource
    if($LASTEXITCODE){throw 'Large fixture generation failed'}
}
$taskOutput=Join-Path $taskFolder ('remux-'+[guid]::NewGuid().ToString('N')+'.mp4')
$taskInfo=[Diagnostics.ProcessStartInfo]::new($taskFfmpeg)
$taskInfo.UseShellExecute=$false
$taskInfo.CreateNoWindow=$true
$taskInfo.RedirectStandardError=$true
foreach($taskArg in @('-v','error','-n','-protocol_whitelist','file,pipe','-i',$taskSource,'-map','0','-c','copy',$taskOutput)){$taskInfo.ArgumentList.Add($taskArg)}
$taskWatch=[Diagnostics.Stopwatch]::StartNew()
$taskProcess=[Diagnostics.Process]::Start($taskInfo)
$taskErrors=$taskProcess.StandardError.ReadToEndAsync()
$taskPeak=0L
do {
    $taskProcess.Refresh()
    $taskPeak=[Math]::Max($taskPeak,$taskProcess.PeakWorkingSet64)
} while(-not $taskProcess.WaitForExit(50))
$taskWatch.Stop()
$taskErrorText=$taskErrors.GetAwaiter().GetResult()
if($taskProcess.ExitCode){throw "Remux failed: $taskErrorText"}
$taskData=& $taskProbe -v error -show_format -show_streams -of json $taskOutput | ConvertFrom-Json
if($LASTEXITCODE){throw 'Output probe failed'}
$taskRecord=[ordered]@{backend='FFmpeg stream copy';inputBytes=(Get-Item $taskSource).Length;outputBytes=(Get-Item $taskOutput).Length;elapsedMs=$taskWatch.ElapsedMilliseconds;peakWorkingSetBytes=$taskPeak;cpuMs=$taskProcess.TotalProcessorTime.TotalMilliseconds;codec=$taskData.streams[0].codec_name;durationSeconds=$taskData.format.duration;output=$taskOutput;success=$true;fixture='repeated generated noisy H264 packets, actual 1GiB file, not sparse';validation='probe only; full decode recorded separately'}
$taskRecord | ConvertTo-Json | Set-Content (Join-Path $taskFolder 'result.json')
$taskRecord | ConvertTo-Json
$taskProcess.Dispose()
