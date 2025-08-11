import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fluent_emoji/flutter_fluent_emoji.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fluent Emoji Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Fluent Emoji Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  EmojiData? _selectedEmoji;
  final List<EmojiData> _recentEmojis = [];

  Future<void> _showEmojiPicker() async {
    final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
      context: context,
      height: MediaQuery.of(context).size.height * 0.6,
      searchHintText: 'Search for emojis...',
    );

    if (emoji != null) {
      setState(() {
        _selectedEmoji = emoji;
        // Add to recent emojis (keep only last 10)
        _recentEmojis.removeWhere((e) => e.unicode == emoji.unicode);
        _recentEmojis.insert(0, emoji);
        if (_recentEmojis.length > 10) {
          _recentEmojis.removeLast();
        }
      });
    }
  }

  Widget _buildFluentEmojiImage(EmojiData emoji, {double size = 48}) {
    final imageUrl = EmojiService.getFluentImageUrl(
      emoji,
      style: EmojiStyle.color,
    );

    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: SizedBox(
              width: size * 0.3,
              height: size * 0.3,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.broken_image, size: size * 0.5),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.emoji_emotions, size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Selected Emoji:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _selectedEmoji != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFluentEmojiImage(_selectedEmoji!, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              _selectedEmoji!.cldr +
                                  (_selectedEmoji!.selectedSkinTone != null
                                      ? ' (${_selectedEmoji!.selectedSkinTone!.value})'
                                      : ''),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const Text(
                          'No emoji selected',
                          style: TextStyle(color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(height: 32),
              if (_recentEmojis.isNotEmpty) ...[
                const Text(
                  'Recent Emojis:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentEmojis
                      .map(
                        (emoji) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedEmoji = emoji;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedEmoji?.unicode == emoji.unicode
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _buildFluentEmojiImage(emoji, size: 24),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 32),
              ],

              // Toggle for using Fluent images in picker
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _showEmojiPicker,
                icon: const Icon(Icons.emoji_emotions),
                label: const Text('Pick an Emoji'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedEmoji != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emoji Details:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Name: ${_selectedEmoji!.cldr}'),
                        Text('Category: ${_selectedEmoji!.group}'),
                        Text('Unicode: ${_selectedEmoji!.unicode}'),
                        Text(
                          'Keywords: ${_selectedEmoji!.keywords.join(', ')}',
                        ),
                        Text(
                          'Skin tone based: ${_selectedEmoji!.isSkintoneBased}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
