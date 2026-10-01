param([string]$Analyzer = "luau-lsp")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$definitionPath = Join-Path $projectRoot ".tools/roblox.d.luau"
$expectedHash = "2857EFA8245485F8C25C19C018EE1EF9B46AFAB4EFD2EA70FC3257CD3FAF7080"
if (-not (Test-Path -LiteralPath $definitionPath)) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $definitionPath) | Out-Null
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau" -OutFile $definitionPath
}
if ((Get-FileHash -LiteralPath $definitionPath -Algorithm SHA256).Hash -ne $expectedHash) {
    throw "Roblox definitions do not match the pinned version."
}
Push-Location $projectRoot
try {
    & $Analyzer analyze --platform roblox --definitions $definitionPath --definitions types/executor.d.luau src tests/types
    if ($LASTEXITCODE -ne 0) { throw "Strict Luau type checking failed." }
} finally {
    Pop-Location
}
