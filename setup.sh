#!/bin/bash

set -e

echo "🚀 Setting up SmartTripPlanner development environment..."

# Check Xcode installation
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"

# Check Homebrew installation
if ! command -v brew &> /dev/null; then
    echo "⚠️  Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "✅ Homebrew found: $(brew --version | head -n 1)"

# Install SwiftLint
if ! command -v swiftlint &> /dev/null; then
    echo "📦 Installing SwiftLint..."
    brew install swiftlint
else
    echo "✅ SwiftLint already installed: $(swiftlint version)"
fi

# Install SwiftFormat
if ! command -v swiftformat &> /dev/null; then
    echo "📦 Installing SwiftFormat..."
    brew install swiftformat
else
    echo "✅ SwiftFormat already installed: $(swiftformat --version)"
fi

# Install fastlane
if ! command -v fastlane &> /dev/null; then
    echo "📦 Installing fastlane..."
    brew install fastlane
else
    echo "✅ fastlane already installed: $(fastlane --version | head -n 1)"
fi

# Copy environment template if needed
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please update .env with your credentials before building"
else
    echo "✅ .env file already exists"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update .env with your Apple Developer and Google credentials"
echo "2. Configure signing in Xcode: open SmartTripPlanner/SmartTripPlanner.xcodeproj"
echo "3. Select your Development Team in Signing & Capabilities"
echo "4. Build and run: Cmd+R in Xcode"
echo ""
echo "For more information, see README.md"
