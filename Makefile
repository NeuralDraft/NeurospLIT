# NeurospLIT Makefile
# Quick commands for building and testing the iOS app

.PHONY: help setup build test clean open archive simulator docs

# Default target: show help
help:
	@echo "NeurospLIT Build Commands:"
	@echo "  make setup     - Setup project (install dependencies, configure secrets)"
	@echo "  make build     - Build the app in Debug configuration"
	@echo "  make test      - Run all unit tests"
	@echo "  make clean     - Clean build artifacts and DerivedData"
	@echo "  make open      - Open project in Xcode"
	@echo "  make archive   - Create release archive for App Store"
	@echo "  make simulator - Open iOS Simulator"
	@echo "  make docs      - Generate documentation"

# Setup project for first-time use
setup:
	@echo "🔧 Setting up NeurospLIT..."
	@if [ ! -f "Configuration/Secrets.xcconfig" ]; then \
		cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig; \
		echo "📝 Created Secrets.xcconfig - Please add your API keys"; \
	fi
	@if [ -f "Scripts/setup.sh" ]; then \
		chmod +x Scripts/setup.sh; \
		./Scripts/setup.sh; \
	fi
	@echo "✅ Setup complete!"

# Build the app
build:
	@echo "🔨 Building NeurospLIT..."
	xcodebuild -scheme NeurospLIT \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		build

# Run tests
test:
	@echo "🧪 Running tests..."
	xcodebuild test \
		-scheme NeurospLIT \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-parallel-testing-enabled YES

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	xcodebuild clean -scheme NeurospLIT
	rm -rf ~/Library/Developer/Xcode/DerivedData/NeurospLIT-*
	rm -rf DerivedData/
	@echo "✅ Clean complete!"

# Open in Xcode
open:
	@echo "📱 Opening NeurospLIT in Xcode..."
	open NeurospLIT.xcodeproj

# Create archive for App Store
archive:
	@echo "📦 Creating App Store archive..."
	xcodebuild archive \
		-scheme NeurospLIT \
		-configuration Release \
		-archivePath ./build/NeurospLIT.xcarchive

# Open iOS Simulator
simulator:
	@echo "📱 Opening iOS Simulator..."
	open -a Simulator

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	@if command -v swift-doc >/dev/null 2>&1; then \
		swift-doc generate NeurospLIT --format html --output docs; \
	else \
		echo "⚠️  swift-doc not installed. Install with: brew install swift-doc"; \
	fi

# Quick build and run
run: build
	@echo "🚀 Running NeurospLIT..."
	xcrun simctl boot "iPhone 15" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "iPhone 15" \
		~/Library/Developer/Xcode/DerivedData/NeurospLIT-*/Build/Products/Debug-iphonesimulator/NeurospLIT.app
	xcrun simctl launch "iPhone 15" net.neuraldraft.NeurospLIT
