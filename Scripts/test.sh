#!/bin/bash
# NeurospLIT Test Script
# Usage: ./Scripts/test.sh

set -e  # Exit on error

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/SupportingFiles/NeurospLIT.xcodeproj"
SCHEME="NeurospLIT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing NeurospLIT...${NC}"
echo -e "${BLUE}   Project: ${PROJECT_FILE}${NC}"
echo ""

# Run tests
echo -e "${YELLOW}🧪 Running unit tests...${NC}"
xcodebuild test \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES

# Check if tests passed
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo -e "${GREEN}Test Summary:${NC}"
    echo -e "${GREEN}   • Service Tests: Passed${NC}"
    echo -e "${GREEN}   • Engine Tests: Passed${NC}"
    echo -e "${GREEN}   • View Tests: Passed${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Tests failed!${NC}"
    echo -e "${RED}   Check test output above${NC}"
    exit 1
fi

