# Build script for Windows Flutter application
# Usage: powershell -ExecutionPolicy Bypass -File .\windows_build.ps1

$ErrorActionPreference = "Stop"

# Configuration
$InnoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$InnoScriptName = "windows_setup.iss"

# Path configuration
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VCLibsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.38.33130\x64\Microsoft.VC143.CRT"
$PubspecPath = Join-Path $ProjectRoot "client\pubspec.yaml"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Flutter Windows Application" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read version from pubspec.yaml for Inno Setup
if (!(Test-Path $PubspecPath)) {
    Write-Host "ERROR: pubspec.yaml not found at: $PubspecPath" -ForegroundColor Red
    exit 1
}

$PubspecContent = Get-Content -Path $PubspecPath -Raw
$VersionMatch = [regex]::Match($PubspecContent, '(?m)^\s*version:\s*([^\s#]+)')

if (!$VersionMatch.Success) {
    Write-Host "ERROR: Failed to parse version from pubspec.yaml" -ForegroundColor Red
    exit 1
}

$AppVersion = $VersionMatch.Groups[1].Value.Trim()
$AppVersion = $AppVersion.Trim("'")
$AppVersion = $AppVersion.Trim('"')
Write-Host "Detected app version: $AppVersion" -ForegroundColor Green
Write-Host ""

# Build Flutter app
Write-Host "[1/2] Building Flutter Windows app (release)..." -ForegroundColor Yellow
$ClientPath = Join-Path $ProjectRoot "client"

Push-Location $ClientPath
try {
    flutter build windows --release
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Flutter build completed successfully." -ForegroundColor Green
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "[2/2] Creating installer with Inno Setup..." -ForegroundColor Yellow

# Compile Inno Setup script with path definitions
$InnoScript = Join-Path $ProjectRoot $InnoScriptName

# Pass path definitions to Inno Setup compiler
$InnoArgs = @(
    "/DProjectRoot=$ProjectRoot"
    "/DVCLibsPath=$VCLibsPath"
    "/DMyAppVersion=$AppVersion"
    $InnoScript
)

& $InnoCompiler @InnoArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Inno Setup compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installer created in: $ProjectRoot" -ForegroundColor Green
Write-Host ""

