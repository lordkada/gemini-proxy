# Run DeepSeek Harness (dsh) in a container, against the proxy, on the current directory (Windows PowerShell).
# Usage: scripts\deepseek-harness.ps1                                Web UI on http://127.0.0.1:3080
#        scripts\deepseek-harness.ps1 headless "explain this repo"   one-shot task
$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $PSScriptRoot
$Image = "gemini-proxy-deepseek-harness"
$Network = "gemini-proxy_default"
$EnvFile = Join-Path $RepoDir ".env"
$Port = if ($env:DSH_PORT) { $env:DSH_PORT } else { "3080" }

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
    docker build @BuildArgs -t $Image (Join-Path $RepoDir "deepseek-harness-container")
}

# The Web UI is the default; only then is a port published, on 127.0.0.1.
$PortArgs = @()
if ($args.Count -eq 0 -or $args[0] -eq "web") {
    $PortArgs = @("-p", "127.0.0.1:${Port}:${Port}", "-e", "DSH_PORT=$Port")
}

docker run --rm -it @PortArgs `
    --network $Network `
    -e "GEMINI_PROXY_API_KEY=$ApiKey" `
    -v "${PWD}:/work" `
    $Image @args
