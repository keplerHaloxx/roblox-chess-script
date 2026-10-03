param([Parameter(Mandatory)][string]$Version)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use a stable X.Y.Z version.' }
$releaseRoot = Split-Path -Parent $PSScriptRoot
$entries = @(
    @{ Path = 'server/package.json'; Pattern = '("version"\s*:\s*")[^"]+' },
    @{ Path = 'server/src-tauri/tauri.conf.json'; Pattern = '("version"\s*:\s*")[^"]+' },
    @{ Path = 'server/src-tauri/Cargo.toml'; Pattern = '(?m)(^version = ")[^"]+' },
    @{ Path = 'server/src-tauri/Cargo.lock'; Pattern = '(?m)(^name = "roblox-chess-script"\r?\nversion = ")[^"]+' }
)
$updates = foreach ($entry in $entries) {
    $path = Join-Path $releaseRoot $entry.Path
    $source = [IO.File]::ReadAllText($path)
    $pattern = [regex]::new($entry.Pattern)
    if ($pattern.Matches($source).Count -ne 1) { throw "Expected one version entry in $path" }
    $updated = $pattern.Replace($source, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $match.Groups[1].Value + $Version })
    @{ Path = $path; Content = $updated }
}
foreach ($update in $updates) {
    [IO.File]::WriteAllText($update.Path, $update.Content, [System.Text.UTF8Encoding]::new($false))
}
Write-Output "Release version set to $Version. Commit and push the changes before running the workflow."
