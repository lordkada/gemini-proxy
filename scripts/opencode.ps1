# Run opencode in a container, against the proxy, on the current directory (Windows PowerShell).
# Usage: scripts\opencode.ps1 [opencode args...]   e.g. scripts\opencode.ps1 run "explain this repo"
$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $PSScriptRoot
$Image = "gemini-proxy-opencode"
$Network = "gemini-proxy_default"
$EnvFile = Join-Path $RepoDir ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing ${EnvFile}: copy .env.example to .env and start the proxy first."
}
$ApiKey = (Get-Content $EnvFile | Where-Object { $_ -match '^PROXY_API_KEY=' } | Select-Object -Last 1) -replace '^PROXY_API_KEY=', ''

docker network inspect $Network *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error "The proxy is not running: run 'docker compose up -d' in $RepoDir first."
}

docker image inspect $Image *> $null
if ($LASTEXITCODE -ne 0 -or $env:REBUILD -eq "1") {
    $BuildArgs = @()
    if ($env:BUILD_NETWORK) { $BuildArgs = @("--network", $env:BUILD_NETWORK) }
    docker build @BuildArgs -t $Image (Join-Path $RepoDir "opencode-container")
}

docker run --rm -it `
    --network $Network `
    -e "GEMINI_PROXY_API_KEY=$ApiKey" `
    -v "${PWD}:/work" `
    $Image @args
