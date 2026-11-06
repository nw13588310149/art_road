# Windows web release build wrapper.
# Flutter incremental web builds on Windows fail with PathExistsException (errno 183)
# when copying assets that already exist under build/web/assets.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $root "build\web\assets"
if (Test-Path $assetsDir) {
  Remove-Item -Recurse -Force $assetsDir
}
Push-Location $root
try {
  flutter build web --release @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
