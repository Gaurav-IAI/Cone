# Builds the current direct-Firebase testing flow. No API URL is required.
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectDirectory
try {
    & node tools/seed/setup_direct_demo_login.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Direct demo login setup failed. APK was not built.' }
    & flutter build apk --release '--dart-define=DIRECT_DEMO_LOGIN=true'
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }
} finally { Pop-Location }
