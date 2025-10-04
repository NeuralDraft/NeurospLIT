# NeurospLIT Setup Script for Windows
# PowerShell version of the setup script

Write-Host "🚀 NeurospLIT Setup Script (Windows)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if running on Windows
if ($env:OS -ne "Windows_NT") {
    Write-Host "This script is for Windows. Use setup.sh for Mac/Linux" -ForegroundColor Yellow
    exit 1
}

# Setup configuration
Write-Host "🔐 Setting up configuration..." -ForegroundColor Green

$secretsPath = "Configuration\Secrets.xcconfig"
$secretsExamplePath = "Configuration\Secrets.example.xcconfig"

if (!(Test-Path $secretsPath)) {
    if (Test-Path $secretsExamplePath) {
        Copy-Item $secretsExamplePath $secretsPath
        Write-Host "📝 Created Secrets.xcconfig from template" -ForegroundColor Yellow
        Write-Host "   Please edit Configuration\Secrets.xcconfig and add your API keys" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Warning: No Secrets.example.xcconfig found" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Secrets.xcconfig already exists" -ForegroundColor Green
}

# Create directories if needed
Write-Host ""
Write-Host "📁 Preparing build directories..." -ForegroundColor Green
if (!(Test-Path "DerivedData")) {
    New-Item -ItemType Directory -Path "DerivedData" -Force | Out-Null
}
Write-Host "✅ Build directories ready" -ForegroundColor Green

# Check for Python and generate icons if possible
if (Get-Command python -ErrorAction SilentlyContinue) {
    if (Test-Path "Scripts\generate_icons.py") {
        Write-Host ""
        Write-Host "🎨 Attempting to generate app icons..." -ForegroundColor Green
        try {
            python Scripts\generate_icons.py 2>$null
            Write-Host "✅ Icons generated" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Icon generation skipped (optional)" -ForegroundColor Yellow
        }
    }
}

# Project information
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Project Structure:" -ForegroundColor Cyan
Write-Host "  - Project File: NeurospLIT.xcodeproj" -ForegroundColor White
Write-Host "  - Source Code:  NeurospLIT\" -ForegroundColor White
Write-Host "  - Tests:        NeurospLITTests\" -ForegroundColor White
Write-Host "  - Scripts:      Scripts\" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Transfer this project to a Mac with Xcode installed" -ForegroundColor White
Write-Host "2. Run: open NeurospLIT.xcodeproj" -ForegroundColor White
Write-Host "   OR" -ForegroundColor Gray
Write-Host "   Push to GitHub and use 'Open with Xcode' feature" -ForegroundColor White
Write-Host "3. Update Configuration\Secrets.xcconfig with your API keys" -ForegroundColor White
Write-Host "4. Select your development team in Xcode" -ForegroundColor White
Write-Host "5. Build and run with Cmd+R" -ForegroundColor White
Write-Host ""
Write-Host "Alternative: Use GitHub's 'Open with Xcode' button!" -ForegroundColor Yellow
Write-Host ""

# Try to open the project file location
$openProject = Read-Host "Open project folder in Explorer? (y/n)"
if ($openProject -eq 'y') {
    Start-Process explorer.exe -ArgumentList "."
}
