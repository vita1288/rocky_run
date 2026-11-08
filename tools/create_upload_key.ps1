# Creates the Rocky Run upload key for Google Play and android/key.properties.
# Run once, from the project folder:   powershell -ExecutionPolicy Bypass -File tools\create_upload_key.ps1
# BACK UP the .jks file and the password: without them you can never update the app.

$ErrorActionPreference = "Stop"
$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (-not (Test-Path $keytool)) { throw "keytool not found at $keytool - adjust the path to your Android Studio jbr folder." }

$keyFile = Join-Path $env:USERPROFILE "rocky-run-upload.jks"
if (Test-Path $keyFile) { throw "$keyFile already exists - keep using it, do not create a new key." }

$secure = Read-Host "Choose a password for the key (min 6 chars)" -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

& $keytool -genkeypair -v -keystore $keyFile -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload -storepass $pass -keypass $pass -dname "CN=Jovita, O=Rocky Run, C=ID"

$props = @"
storePassword=$pass
keyPassword=$pass
keyAlias=upload
storeFile=$($keyFile -replace '\\','/')
"@
Set-Content -Path (Join-Path $PSScriptRoot "..\android\key.properties") -Value $props -Encoding ASCII

Write-Host ""
Write-Host "Done. Key: $keyFile"
Write-Host "Created android\key.properties (git-ignored)."
Write-Host "NOW back up $keyFile and your password somewhere safe."
