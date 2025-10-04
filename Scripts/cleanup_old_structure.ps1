# NeurospLIT - Cleanup Old Directory Structure
# WARNING: Only run this AFTER verifying the new structure works!
# Usage: .\Scripts\cleanup_old_structure.ps1 [-Force]

param(
    [switch]$Force
)

$ProjectDir = Split-Path -Parent $PSScriptRoot

Write-Host "⚠️  NeurospLIT Old Structure Cleanup" -ForegroundColor Yellow
Write-Host ""

$OldDirs = @(
    "App",
    "Views",
    "Services",
    "Engine",
    "Utilities",
    "Tests",
    "Configs",
    "Docs",
    "Resources"
)

Write-Host "The following directories will be PERMANENTLY DELETED:" -ForegroundColor Yellow
foreach ($dir in $OldDirs) {
    $fullPath = Join-Path $ProjectDir $dir
    if (Test-Path $fullPath) {
        Write-Host "   • $dir" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "New structure is in:" -ForegroundColor Green
Write-Host "   • NeurospLIT/" -ForegroundColor Green
Write-Host "   • NeurospLITTests/" -ForegroundColor Green
Write-Host "   • Configuration/" -ForegroundColor Green
Write-Host "   • Documentation/" -ForegroundColor Green
Write-Host ""

if (-not $Force) {
    Write-Host "⚠️  SAFETY CHECK:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Before running this script, ensure:" -ForegroundColor Yellow
    Write-Host "   1. Xcode project has been updated with new file references" -ForegroundColor Yellow
    Write-Host "   2. App builds successfully (⌘B)" -ForegroundColor Yellow
    Write-Host "   3. All tests pass (⌘U)" -ForegroundColor Yellow
    Write-Host "   4. App runs on simulator (⌘R)" -ForegroundColor Yellow
    Write-Host ""
    
    $confirmation = Read-Host "Type 'DELETE' to proceed with cleanup (or anything else to cancel)"
    
    if ($confirmation -ne "DELETE") {
        Write-Host ""
        Write-Host "❌ Cleanup cancelled." -ForegroundColor Red
        Write-Host "   This is the safe choice! Only proceed after full verification." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""
Write-Host "🗑️  Removing old directories..." -ForegroundColor Yellow

foreach ($dir in $OldDirs) {
    $fullPath = Join-Path $ProjectDir $dir
    if (Test-Path $fullPath) {
        Write-Host "   Removing: $dir" -ForegroundColor Red
        Remove-Item -Recurse -Force $fullPath
    }
}

Write-Host ""
Write-Host "✅ Cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Your project now has a clean, organized structure." -ForegroundColor Green
Write-Host "All files are in:" -ForegroundColor Green
Write-Host "   • NeurospLIT/" -ForegroundColor Green
Write-Host "   • NeurospLITTests/" -ForegroundColor Green
Write-Host "   • Configuration/" -ForegroundColor Green
Write-Host "   • Documentation/" -ForegroundColor Green
Write-Host ""

