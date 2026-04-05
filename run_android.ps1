# Run Student Swipe on Android Emulator
# Fixes path issues when Windows username contains spaces (e.g. "Si004 (293400)")

$env:ANDROID_HOME = "C:\Android\Sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\Sdk"

# Use C:\Projects\student_swipe (no spaces) to avoid Gradle/CMake path issues
$projectDir = "C:\Projects\student_swipe"
$sourceDir = $PSScriptRoot

if (-not (Test-Path $projectDir)) {
    New-Item -ItemType Directory -Path (Split-Path $projectDir) -Force | Out-Null
}

# Sync source files (exclude build artifacts)
Write-Host "Syncing project to $projectDir..."
robocopy $sourceDir $projectDir /E /XD build .dart_tool .git /NFL /NDL /NJH /NJS | Out-Null

# Ensure local.properties uses C:\Android\Sdk (avoids path-with-spaces issues)
$localProps = "$projectDir\android\local.properties"
(Get-Content $localProps) -replace 'sdk\.dir=.*', 'sdk.dir=C:\\Android\\Sdk' | Set-Content $localProps

Set-Location $projectDir
flutter run -d emulator-5554
