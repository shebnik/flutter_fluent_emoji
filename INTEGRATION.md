# Integration Guide

## Quick Start

1. **Add the dependency** to your `pubspec.yaml`:
```yaml
dependencies:
  flutter_fluent_emoji: ^0.0.1
```

2. **Import the package**:
```dart
import 'package:flutter_fluent_emoji/flutter_fluent_emoji.dart';
```

3. **Show the emoji picker**:
```dart
final emoji = await FluentEmojiPicker.showEmojiBottomSheet(context: context);
if (emoji != null) {
  // Use the selected emoji
  print('Selected: ${emoji.glyph}');
}
```

## Common Use Cases

### Chat Application
```dart
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  void _showEmojiPicker() async {
    final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
      context: context,
      height: 300,
    );
    
    if (emoji != null) {
      _messageController.text += emoji.glyph;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: MessageList()),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(hintText: 'Type a message...'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.emoji_emotions),
                onPressed: _showEmojiPicker,
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () => _sendMessage(_messageController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### Reaction Picker
```dart
class ReactionPicker extends StatelessWidget {
  final Function(EmojiData) onReactionSelected;

  const ReactionPicker({required this.onReactionSelected});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.add_reaction),
      onPressed: () async {
        final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
          context: context,
          height: 250,
          showSearch: false, // Hide search for quick reactions
        );
        
        if (emoji != null) {
          onReactionSelected(emoji);
        }
      },
    );
  }
}
```

### Profile Emoji Selection
```dart
class ProfileEmojiSelector extends StatefulWidget {
  @override
  _ProfileEmojiSelectorState createState() => _ProfileEmojiSelectorState();
}

class _ProfileEmojiSelectorState extends State<ProfileEmojiSelector> {
  EmojiData? selectedEmoji;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            selectedEmoji?.glyph ?? '😊',
            style: TextStyle(fontSize: 24),
          ),
        ),
        title: Text('Profile Emoji'),
        subtitle: Text(selectedEmoji?.cldr ?? 'Tap to select'),
        trailing: Icon(Icons.edit),
        onTap: () async {
          final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
            context: context,
            defaultStyle: EmojiStyle.color,
            height: MediaQuery.of(context).size.height * 0.7,
          );
          
          if (emoji != null) {
            setState(() {
              selectedEmoji = emoji;
            });
          }
        },
      ),
    );
  }
}
```

## Performance Tips

1. **Use default style** (3D) when possible for better performance
2. **Implement your own caching** for frequently used emojis
3. **Limit search results** for better UX in large datasets
4. **Preload categories** that users access most

## Customization

### Theme Integration
```dart
FluentEmojiPicker.showEmojiBottomSheet(
  context: context,
  backgroundColor: Theme.of(context).colorScheme.surface,
  categoryTextStyle: Theme.of(context).textTheme.titleSmall,
)
```

### Custom Styling
```dart
FluentEmojiPicker(
  height: 350,
  backgroundColor: Colors.grey[50],
  categoryTextStyle: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
  ),
)
```
