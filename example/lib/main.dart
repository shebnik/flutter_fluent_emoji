import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fluent_emoji/flutter_fluent_emoji.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? imageUrl;
  final List<EmojiData> _recentEmojis = [];
  EmojiStyle _selectedStyle = EmojiStyle.threeDimensional;

  Future<void> _showEmojiPicker() async {
    final emoji = await FluentEmojiPicker.showEmojiBottomSheet(
      context: context,
      height: MediaQuery.of(context).size.height * 0.6,
      searchHintText: 'Search for emojis...',
      showSearch: true,
    );

    if (emoji != null) {
      setState(() {
        _selectedEmoji = emoji;
        _recentEmojis.removeWhere((e) => e.unicode == emoji.unicode);
        _recentEmojis.insert(0, emoji);
        if (_recentEmojis.length > 10) {
          _recentEmojis.removeLast();
        }
      });
    }
  }

  Widget _buildFluentEmojiImage(String imageUrl, {double size = 48}) {
    if (imageUrl.isEmpty) {
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

    return ExtendedImage.network(
      imageUrl,
      key: ValueKey(imageUrl),
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedEmoji != null) {
      imageUrl = EmojiService.getFluentImageUrl(
        _selectedEmoji!,
        style: _selectedStyle,
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            const Text('Selected Emoji:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),

            // Selected emoji preview
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _selectedEmoji != null && imageUrl != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFluentEmojiImage(imageUrl!, size: 100),
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
            const SizedBox(height: 8),

            // Style selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Emoji Style: "),
                DropdownButton<EmojiStyle>(
                  value: _selectedStyle,
                  onChanged: (style) {
                    if (style != null) {
                      setState(() => _selectedStyle = style);
                    }
                  },
                  items: EmojiStyle.values.map((style) {
                    return DropdownMenuItem(
                      value: style,
                      child: Text(style.value),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Recent emojis
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
                          child: _buildFluentEmojiImage(
                            EmojiService.getFluentImageUrl(
                              emoji,
                              style: _selectedStyle,
                            ),
                            size: 24,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],

            // Pick emoji button
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

            // Details
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
                      Text('Keywords: ${_selectedEmoji!.keywords.join(', ')}'),
                      Text(
                        'Skin tone based: ${_selectedEmoji!.isSkintoneBased}',
                      ),
                      if (_selectedEmoji!.styles != null) ...[
                        Text('Styles:'),
                        for (final style in _selectedEmoji!.styles!.entries)
                          ListTile(
                            visualDensity: VisualDensity.compact,
                            dense: true,
                            onTap: () => launchUrl(Uri.parse(style.value)),
                            title: Text('${style.key} - ${style.value}'),
                          ),
                      ],
                      if (_selectedEmoji!.skintones != null) ...[
                        Text('Skin Tones:'),
                        for (final skinTone
                            in _selectedEmoji!.skintones!.keys) ...[
                          Text(skinTone),
                          if (_selectedEmoji!.skintones![skinTone] != null)
                            for (final style
                                in _selectedEmoji!
                                    .skintones![skinTone]!
                                    .entries)
                              ListTile(
                                visualDensity: VisualDensity.compact,
                                dense: true,
                                onTap: () => launchUrl(Uri.parse(style.value)),
                                title: Text('${style.key} - ${style.value}'),
                              ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
