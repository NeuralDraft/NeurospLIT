#!/bin/bash

# NeurospLIT Quick Setup Script
# This script prepares a fresh clone for immediate development

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 NeurospLIT Setup Script"
echo "========================="
echo ""

# Check for Xcode
echo "📱 Checking for Xcode..."
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: Xcode is not installed${NC}"
    echo "Please install Xcode from the Mac App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1 | awk '{print $2}')
echo -e "${GREEN}✅ Xcode ${XCODE_VERSION} found${NC}"

# Check for minimum Xcode version
MIN_VERSION="15.0"
if [ -f ".xcode-version" ]; then
    MIN_VERSION=$(cat .xcode-version)
fi

# Simple version comparison (works for X.Y format)
if [ "$(printf '%s\n' "$MIN_VERSION" "$XCODE_VERSION" | sort -V | head -n1)" != "$MIN_VERSION" ]; then
    echo -e "${YELLOW}⚠️  Warning: Xcode $XCODE_VERSION is older than recommended $MIN_VERSION${NC}"
fi

# Setup secrets configuration
echo ""
echo "🔐 Setting up configuration..."
if [ ! -f "Configuration/Secrets.xcconfig" ]; then
    if [ -f "Configuration/Secrets.example.xcconfig" ]; then
        cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig
        echo -e "${YELLOW}📝 Created Secrets.xcconfig from template${NC}"
        echo -e "${YELLOW}   Please edit Configuration/Secrets.xcconfig and add your API keys${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: No Secrets.example.xcconfig found${NC}"
    fi
else
    echo -e "${GREEN}✅ Secrets.xcconfig already exists${NC}"
fi

# Create DerivedData directory if needed
echo ""
echo "📁 Preparing build directories..."
mkdir -p DerivedData
echo -e "${GREEN}✅ Build directories ready${NC}"

# Install Swift Package Dependencies (if Package.swift exists)
if [ -f "Package.swift" ]; then
    echo ""
    echo "📦 Resolving Swift Package dependencies..."
    xcodebuild -resolvePackageDependencies
    echo -e "${GREEN}✅ Package dependencies resolved${NC}"
fi

# Generate icons if script exists
if [ -f "Scripts/generate_icons.py" ] && command -v python3 &> /dev/null; then
    echo ""
    echo "🎨 Generating app icons..."
    python3 Scripts/generate_icons.py 2>/dev/null || echo -e "${YELLOW}⚠️  Icon generation skipped (optional)${NC}"
fi

# Clean any previous builds
echo ""
echo "🧹 Cleaning previous builds..."
xcodebuild clean -scheme NeurospLIT -quiet 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/NeurospLIT-* 2>/dev/null || true
echo -e "${GREEN}✅ Clean complete${NC}"

# Attempt a test build
echo ""
echo "🔨 Testing build configuration..."
if xcodebuild -scheme NeurospLIT \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -configuration Debug \
    -quiet \
    build-for-testing 2>/dev/null; then
    echo -e "${GREEN}✅ Build configuration verified${NC}"
else
    echo -e "${YELLOW}⚠️  Build test failed - you may need to configure the project in Xcode${NC}"
fi

# Open in Xcode
echo ""
echo "📱 Opening project in Xcode..."
open NeurospLIT.xcodeproj

echo ""
echo "========================================="
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. If needed, update Configuration/Secrets.xcconfig with your API keys"
echo "2. Select your development team in Xcode project settings"
echo "3. Build and run with ⌘+R"
echo ""
echo "Quick commands:"
echo "  make build  - Build the project"
echo "  make test   - Run tests"
echo "  make clean  - Clean build artifacts"
echo "  make help   - Show all available commands"
echo ""
echo "Happy coding! 🚀"
