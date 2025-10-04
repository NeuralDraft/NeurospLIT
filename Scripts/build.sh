#!/bin/bash
# NeurospLIT Build Script
# Usage: ./Scripts/build.sh [debug|release]

set -e  # Exit on error

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/SupportingFiles/NeurospLIT.xcodeproj"
SCHEME="NeurospLIT"
CONFIGURATION="${1:-Debug}"  # Default to Debug if not specified

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏗️  Building NeurospLIT...${NC}"
echo -e "${BLUE}   Configuration: ${CONFIGURATION}${NC}"
echo -e "${BLUE}   Project: ${PROJECT_FILE}${NC}"
echo ""

# Clean build folder
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
xcodebuild -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  clean

echo ""

# Build for iOS Simulator
echo -e "${YELLOW}🔨 Building for iOS Simulator...${NC}"
xcodebuild -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${GREEN}   Configuration: ${CONFIGURATION}${NC}"
    echo -e "${GREEN}   Ready to run on simulator${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Build failed!${NC}"
    echo -e "${RED}   Check error messages above${NC}"
    exit 1
fi

