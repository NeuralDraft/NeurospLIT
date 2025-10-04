#!/bin/bash
# NeurospLIT Archive Script for App Store
# Usage: ./Scripts/archive.sh

set -e  # Exit on error

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/SupportingFiles/NeurospLIT.xcodeproj"
SCHEME="NeurospLIT"
ARCHIVE_PATH="$PROJECT_DIR/build/NeurospLIT.xcarchive"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Archiving NeurospLIT for App Store...${NC}"
echo -e "${BLUE}   Project: ${PROJECT_FILE}${NC}"
echo -e "${BLUE}   Archive: ${ARCHIVE_PATH}${NC}"
echo ""

# Clean first
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
xcodebuild -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  clean

echo ""

# Create archive
echo -e "${YELLOW}📦 Creating archive...${NC}"
xcodebuild archive \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH"

# Check if archive succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Archive created successfully!${NC}"
    echo -e "${GREEN}   Location: ${ARCHIVE_PATH}${NC}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "${GREEN}   1. Open Xcode > Window > Organizer${NC}"
    echo -e "${GREEN}   2. Select the archive${NC}"
    echo -e "${GREEN}   3. Click 'Validate App'${NC}"
    echo -e "${GREEN}   4. Click 'Distribute App'${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Archive failed!${NC}"
    echo -e "${RED}   Check error messages above${NC}"
    exit 1
fi

