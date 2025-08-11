# Flutter Fluent Emoji

A Flutter plugin for displaying Microsoft Fluent Emoji in a bottom sheet picker, similar to the React project at [fluentemoji.com](https://fluentemoji.com).

## Features

- 🎨 **Multiple Styles**: Support for 3D, Color, Flat, High Contrast, and Animated emoji styles
- 🌈 **Skin Tone Support**: Full skin tone variations for applicable emojis
- 🔍 **Search Functionality**: Search emojis by name, keywords, or description
- 📱 **Responsive Design**: Adaptive grid layout for different screen sizes
- ⚡ **Performance Optimized**: Uses native emoji glyphs for default style, network images for custom styles
- 💾 **Caching**: One-time fetch with intelligent caching system
- 🎭 **Categories**: Browse emojis by categories (Smileys & Emotion, People & Body, etc.)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_fluent_emoji: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Usage

```dart
import 'package:flutter_fluent_emoji/flutter_fluent_emoji.dart';

// Show emoji picker as bottom sheet
final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
  context: context,
);

if (emoji != null) {
  print('Selected emoji: ${emoji.glyph} (${emoji.cldr})');
}
```

### Advanced Usage

```dart
final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
  context: context,
  height: MediaQuery.of(context).size.height * 0.6,
  defaultStyle: EmojiStyle.threeDimensional,
  defaultSkinTone: SkinTone.defaultTone,
  showSearch: true,
  searchHintText: 'Search for emojis...',
  backgroundColor: Colors.white,
  categoryTextStyle: TextStyle(fontWeight: FontWeight.bold),
);
```

### Custom Widget

You can also use the picker as a regular widget:

```dart
FluentEmojiPicker(
  onEmojiSelected: (emoji) {
    print('Selected: ${emoji.glyph}');
  },
  defaultStyle: EmojiStyle.color,
  height: 400,
  showSearch: true,
)
```

## API Reference

### FluentEmojiPicker

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `onEmojiSelected` | `Function(EmojiData)?` | `null` | Callback when emoji is selected |
| `defaultStyle` | `EmojiStyle` | `EmojiStyle.threeDimensional` | Default emoji style |
| `defaultSkinTone` | `SkinTone` | `SkinTone.defaultTone` | Default skin tone |
| `height` | `double` | `400` | Height of the picker |
| `backgroundColor` | `Color?` | `null` | Background color |
| `categoryTextStyle` | `TextStyle?` | `null` | Style for category tabs |
| `showSearch` | `bool` | `true` | Show search bar |
| `searchHintText` | `String` | `'Search emojis...'` | Search placeholder text |

### EmojiData

Contains all emoji information:

```dart
class EmojiData {
  final String cldr;           // Human-readable name
  final String glyph;          // Emoji character (e.g., "😀")
  final String group;          // Category (e.g., "Smileys & Emotion")
  final List<String> keywords; // Search keywords
  final String unicode;        // Unicode identifier
  final bool isSkintoneBased;  // Supports skin tones
  // ... and more
}
```

### Enums

#### EmojiStyle
- `EmojiStyle.threeDimensional` - 3D style (default, uses native glyph)
- `EmojiStyle.color` - Color style
- `EmojiStyle.flat` - Flat style
- `EmojiStyle.highContrast` - High contrast style
- `EmojiStyle.animated` - Animated style

#### SkinTone
- `SkinTone.defaultTone` - Default skin tone
- `SkinTone.light` - Light skin tone
- `SkinTone.mediumLight` - Medium-light skin tone
- `SkinTone.medium` - Medium skin tone
- `SkinTone.mediumDark` - Medium-dark skin tone
- `SkinTone.dark` - Dark skin tone

## Performance Notes

- **Default Style**: Uses native emoji glyphs (e.g., "😀") for optimal performance
- **Custom Styles**: Downloads images from Microsoft's CDN when needed
- **Caching**: Images are cached using `cached_network_image`
- **Lazy Loading**: Emojis are loaded by category to improve initial load time

## Data Source

This plugin uses emoji metadata from Microsoft's [Fluent Emoji repository](https://github.com/microsoft/fluentui-emoji). The data is fetched once and cached for subsequent uses.

## Example

Check out the [example](example/) directory for a complete demo app.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

- Microsoft Fluent Emoji: https://github.com/microsoft/fluentui-emoji
- Original React implementation: https://fluentemoji.com
