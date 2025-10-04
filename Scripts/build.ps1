# NeurospLIT Build Script (PowerShell)
# Usage: .\Scripts\build.ps1 [-Configuration Debug|Release]

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

# Configuration
$ProjectDir = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectDir "SupportingFiles\NeurospLIT.xcodeproj"
$Scheme = "NeurospLIT"

Write-Host "🏗️  Building NeurospLIT..." -ForegroundColor Blue
Write-Host "   Configuration: $Configuration" -ForegroundColor Blue
Write-Host "   Project: $ProjectFile" -ForegroundColor Blue
Write-Host ""

# Clean build folder
Write-Host "🧹 Cleaning build folder..." -ForegroundColor Yellow
xcodebuild -project $ProjectFile -scheme $Scheme clean

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Clean failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Build for iOS Simulator
Write-Host "🔨 Building for iOS Simulator..." -ForegroundColor Yellow
xcodebuild -project $ProjectFile `
  -scheme $Scheme `
  -configuration $Configuration `
  -sdk iphonesimulator `
  -destination 'platform=iOS Simulator,name=iPhone 15' `
  build

# Check if build succeeded
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host "   Configuration: $Configuration" -ForegroundColor Green
    Write-Host "   Ready to run on simulator" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Write-Host "   Check error messages above" -ForegroundColor Red
    exit 1
}

