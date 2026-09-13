# Flutter supports links to local plugins. Windows directory junctions work
# without elevation when Developer Mode/symbolic-link privileges are absent.
# Run after dependencies resolve; this script never changes SDK or package files.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestPath = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Run flutter pub get first to resolve the actual plugin paths.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$linksRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'windows/flutter/ephemeral/.plugin_symlinks'))
if (-not $linksRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Plugin link directory is outside the project.'
}
New-Item -ItemType Directory -Force -Path $linksRoot | Out-Null
foreach ($plugin in $manifest.plugins.windows) {
    if ($plugin.name -notmatch '^[a-z0-9_]+$') { throw 'Invalid plugin name in generated manifest.' }
    $target = (Resolve-Path -LiteralPath $plugin.path).ProviderPath
    if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Plugin target is not a directory.' }
    $link = Join-Path $linksRoot $plugin.name
    if (Test-Path -LiteralPath $link) {
        $existing = Get-Item -LiteralPath $link -Force
        if (-not $existing.LinkType) { throw "Existing plugin path is not a link: $link" }
        if ([IO.Path]::GetFullPath($existing.Target).TrimEnd('\') -ne [IO.Path]::GetFullPath($target).TrimEnd('\')) {
            throw "Existing link points to a different package; inspect before replacing: $link"
        }
    } else {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
    Get-Item -LiteralPath $link | Select-Object Name, LinkType, Target
}
