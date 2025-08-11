#!/bin/bash

# Flutter Fluent Emoji Demo Script

echo "🚀 Flutter Fluent Emoji Demo"
echo "=============================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter found"

# Navigate to the example directory
cd "$(dirname "$0")/example"

echo "📦 Getting dependencies..."
flutter pub get

echo "🔍 Analyzing code..."
flutter analyze

if [ $? -eq 0 ]; then
    echo "✅ Analysis passed"
else
    echo "❌ Analysis failed"
    exit 1
fi

echo "🧪 Running tests..."
cd ..
flutter test

if [ $? -eq 0 ]; then
    echo "✅ All tests passed"
else
    echo "❌ Some tests failed"
    exit 1
fi

echo ""
echo "🎉 Ready to run!"
echo "To start the demo app, run:"
echo "  cd example"
echo "  flutter run"
echo ""
echo "Features to try:"
echo "  • Tap 'Pick an Emoji' to open the bottom sheet"
echo "  • Browse categories by swiping tabs"
echo "  • Search for emojis using the search bar"
echo "  • Change styles and skin tones"
echo "  • Tap on recent emojis to reselect them"
