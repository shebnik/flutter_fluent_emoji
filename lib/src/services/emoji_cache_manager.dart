import 'package:flutter/foundation.dart';
import 'package:flutter_fluent_emoji/flutter_fluent_emoji.dart';

// Global cache manager for persistent storage across widget lifecycles
class EmojiCacheManager {
  static final EmojiCacheManager _instance = EmojiCacheManager._internal();
  factory EmojiCacheManager() => _instance;
  EmojiCacheManager._internal();

  // Persistent caches that survive widget disposal
  // Now keyed by both category and style: "category:style"
  final Map<String, List<EmojiData>> _categoryDataCache = {};
  final Map<String, bool> _categoryFullyLoaded = {};
  final Map<String, Map<String, Uint8List>> _imageCache = {};
  final Set<String> _loadingCategories = {};

  // Helper method to create cache key
  String _getCacheKey(String category, EmojiStyle style) {
    return '$category:${style.value}';
  }

  // Getters for cache access (these remain for backward compatibility)
  Map<String, List<EmojiData>> get categoryDataCache => _categoryDataCache;
  Map<String, bool> get categoryFullyLoaded => _categoryFullyLoaded;
  Map<String, Map<String, Uint8List>> get imageCache => _imageCache;
  Set<String> get loadingCategories => _loadingCategories;

  // Clear all caches (useful for complete reset)
  void clearAllCaches() {
    _categoryDataCache.clear();
    _categoryFullyLoaded.clear();
    _imageCache.clear();
    _loadingCategories.clear();
  }

  // Clear caches for a specific style change
  void clearCachesForStyleChange() {
    _categoryFullyLoaded.clear();
    _imageCache.clear();
    // Keep category data cache as it doesn't depend on style
  }

  // Clear caches for a specific style only
  void clearCachesForStyle(EmojiStyle style) {
    // Remove entries for this specific style
    final keysToRemove = <String>[];

    for (final key in _categoryFullyLoaded.keys) {
      if (key.endsWith(':${style.value}')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _categoryFullyLoaded.remove(key);
      _imageCache.remove(key);
    }

    // Remove loading states for this style
    _loadingCategories.removeWhere((key) => key.endsWith(':${style.value}'));
  }

  bool isCategoryFullyLoaded(String category, EmojiStyle style) {
    final key = _getCacheKey(category, style);
    return _categoryFullyLoaded[key] == true;
  }

  void markCategoryAsLoaded(String category, EmojiStyle style) {
    final key = _getCacheKey(category, style);
    _categoryFullyLoaded[key] = true;
  }

  void markCategoryAsLoading(String category, EmojiStyle style) {
    final key = _getCacheKey(category, style);
    _loadingCategories.add(key);
  }

  void markCategoryAsNotLoading(String category, EmojiStyle style) {
    final key = _getCacheKey(category, style);
    _loadingCategories.remove(key);
  }

  bool isCategoryLoading(String category, EmojiStyle style) {
    final key = _getCacheKey(category, style);
    return _loadingCategories.contains(key);
  }

  List<EmojiData> getCategoryEmojis(String category, EmojiStyle style) {
    final key = _getCacheKey(category, style);
    return _categoryDataCache[key] ?? [];
  }

  void setCategoryEmojis(
    String category,
    EmojiStyle style,
    List<EmojiData> emojis,
  ) {
    final key = _getCacheKey(category, style);
    _categoryDataCache[key] = emojis;
  }

  Map<String, Uint8List> getCategoryImageCache(
    String category,
    EmojiStyle style,
  ) {
    final key = _getCacheKey(category, style);
    if (!_imageCache.containsKey(key)) {
      _imageCache[key] = {};
    }
    return _imageCache[key]!;
  }

  // Fixed getCachedImage method - finds cached image using emoji's cache key
  Uint8List? getCachedImage(EmojiData emoji, EmojiStyle style) {
    // If emoji has a cache key, use it to find the image URL
    if (emoji.cacheKey != null) {
      // Search through all category image caches for this image
      for (final categoryCache in _imageCache.values) {
        // Generate the expected image URL for this emoji
        final imageUrl = EmojiService.getEmojiImageUrl(
          emoji,
          style: style,
          skinTone: emoji.selectedSkinTone ?? SkinTone.defaultTone,
        );

        if (categoryCache.containsKey(imageUrl)) {
          final cachedBytes = categoryCache[imageUrl];
          if (cachedBytes != null && cachedBytes.isNotEmpty) {
            return cachedBytes;
          }
        }
      }
    }
    return null;
  }

  // Helper method to get cached image by URL (more direct)
  Uint8List? getCachedImageByUrl(String imageUrl) {
    for (final categoryCache in _imageCache.values) {
      if (categoryCache.containsKey(imageUrl)) {
        final cachedBytes = categoryCache[imageUrl];
        if (cachedBytes != null && cachedBytes.isNotEmpty) {
          return cachedBytes;
        }
      }
    }
    return null;
  }

  // Debug method to show cache status
  void printCacheStatus() {
    debugPrint('=== Cache Status ===');
    debugPrint('Category Data Cache: ${_categoryDataCache.length} entries');
    debugPrint('Fully Loaded: ${_categoryFullyLoaded.length} entries');
    debugPrint('Image Cache: ${_imageCache.length} entries');
    debugPrint('Loading: ${_loadingCategories.length} entries');

    for (final key in _categoryDataCache.keys) {
      final emojisCount = _categoryDataCache[key]?.length ?? 0;
      final isLoaded = _categoryFullyLoaded[key] ?? false;
      final imageCount = _imageCache[key]?.length ?? 0;
      debugPrint(
        '  $key: $emojisCount emojis, loaded: $isLoaded, images: $imageCount',
      );
    }
  }
}
