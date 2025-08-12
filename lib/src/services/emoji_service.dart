import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/emoji_data.dart';

class EmojiService {
  static const String _metadataUrl =
      'https://raw.githubusercontent.com/xsalazar/fluent-emoji/refs/heads/main/scripts/metadata.json';

  static Map<String, EmojiData>? _cachedEmojis;
  static Completer<Map<String, EmojiData>>? _loadingCompleter;

  /// Get all emojis, loading from cache or network if needed
  static Future<Map<String, EmojiData>> getEmojis() async {
    if (_cachedEmojis != null) {
      return _cachedEmojis!;
    }

    if (_loadingCompleter != null) {
      // Wait for ongoing loading to complete
      return _loadingCompleter!.future;
    }

    _loadingCompleter = Completer<Map<String, EmojiData>>();

    try {
      // Try to load from local cache first
      final cachedData = await _loadFromCache();
      if (cachedData != null) {
        _cachedEmojis = cachedData;
        _loadingCompleter!.complete(_cachedEmojis!);
        _loadingCompleter = null;
        return _cachedEmojis!;
      }

      // If no cache, load from network
      final networkData = await _loadFromNetwork();
      _cachedEmojis = networkData;

      // Cache the data
      await _saveToCache(networkData);

      _loadingCompleter!.complete(_cachedEmojis!);
      _loadingCompleter = null;
      return _cachedEmojis!;
    } catch (e) {
      _loadingCompleter!.completeError(e);
      _loadingCompleter = null;
      if (kDebugMode) {
        print('Error loading emoji data: $e');
      }
      rethrow;
    }
  }

  /// Get emojis by category
  static Future<List<EmojiData>> getEmojisByCategory(
    String category,
    EmojiStyle style,
  ) async {
    final allEmojis = await getEmojis();
    return allEmojis.values
        .where(
          (emoji) =>
              emoji.group == category &&
              ((emoji.styles?.containsKey(style.value) ?? false) ||
                  (emoji.skintones?.values.any(
                        (skinToneStyles) =>
                            skinToneStyles.containsKey(style.value),
                      ) ??
                      false)),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get all unique categories
  static Future<List<String>> getCategories() async {
    final allEmojis = await getEmojis();
    final categories = allEmojis.values
        .map((emoji) => emoji.group)
        .toSet()
        .toList();

    // Sort categories by the first emoji's sort order in each category
    final categoryOrder = <String, int>{};
    for (final emoji in allEmojis.values) {
      if (!categoryOrder.containsKey(emoji.group)) {
        categoryOrder[emoji.group] = emoji.sortOrder;
      }
    }

    categories.sort(
      (a, b) => (categoryOrder[a] ?? 0).compareTo(categoryOrder[b] ?? 0),
    );
    return categories;
  }

  /// Search emojis by keyword
  static Future<List<EmojiData>> searchEmojis(String query) async {
    if (query.isEmpty) return [];

    final allEmojis = await getEmojis();
    final lowercaseQuery = query.toLowerCase();

    return allEmojis.values
        .where(
          (emoji) =>
              emoji.cldr.toLowerCase().contains(lowercaseQuery) ||
              emoji.keywords.any(
                (keyword) => keyword.toLowerCase().contains(lowercaseQuery),
              ) ||
              emoji.tts.toLowerCase().contains(lowercaseQuery),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Load emoji data from network
  static Future<Map<String, EmojiData>> _loadFromNetwork() async {
    try {
      final response = await http.get(Uri.parse(_metadataUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final Map<String, EmojiData> emojis = {};

        jsonData.forEach((key, value) {
          emojis[key] = EmojiData.fromJson(value);
        });

        return emojis;
      } else {
        throw Exception('Failed to load emoji data: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Network error loading emojis: $e');
      }
      throw Exception('Failed to load emoji data from network: $e');
    }
  }

  /// Load emoji data from cache (platform-specific implementation)
  static Future<Map<String, EmojiData>?> _loadFromCache() async {
    try {
      // This is a simplified cache implementation
      // In a real app, you might want to use shared_preferences or hive
      return null; // For now, always load from network
    } catch (e) {
      if (kDebugMode) {
        print('Cache load error: $e');
      }
      return null;
    }
  }

  /// Save emoji data to cache (platform-specific implementation)
  static Future<void> _saveToCache(Map<String, EmojiData> emojis) async {
    try {
      // This is a simplified cache implementation
      // In a real app, you might want to use shared_preferences or hive
      // For now, we just keep it in memory
    } catch (e) {
      if (kDebugMode) {
        print('Cache save error: $e');
      }
    }
  }

  /// Clear the cache
  static Future<void> clearCache() async {
    _cachedEmojis = null;
    // Clear persistent cache too if implemented
  }

  /// Get emoji image URL
  static String getEmojiImageUrl(
    EmojiData emoji, {
    EmojiStyle style = EmojiStyle.threeDimensional,
    SkinTone skinTone = SkinTone.defaultTone,
  }) {
    if (emoji.isSkintoneBased && emoji.skintones != null) {
      final skinToneStyles = emoji.skintones![skinTone.value];
      final url = skinToneStyles?[style.value];
      if (url != null) {
        return url;
      }
    } else if (emoji.styles != null) {
      final url = emoji.styles![style.value];
      if (url != null) {
        return url;
      }
    }
    return '';
  }

  /// Get the effective skin tone for an emoji (considering selectedSkinTone)
  static SkinTone getEffectiveSkinTone(EmojiData emoji) {
    return emoji.selectedSkinTone ?? SkinTone.defaultTone;
  }

  /// Get Fluent emoji image URL for display (always returns image URL if available)
  static String getFluentImageUrl(
    EmojiData emoji, {
    EmojiStyle style = EmojiStyle.color, // Default to Color style for display
    SkinTone? skinTone,
  }) {
    final effectiveSkinTone = skinTone ?? getEffectiveSkinTone(emoji);
    return getEmojiImageUrl(emoji, style: style, skinTone: effectiveSkinTone);
  }
}
