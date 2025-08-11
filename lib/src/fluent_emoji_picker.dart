import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'models/emoji_data.dart';
import 'services/emoji_service.dart';

final _cacheManager = _EmojiCacheManager();

class FluentEmojiPicker extends StatefulWidget {
  final Function(EmojiData)? onEmojiSelected;
  final EmojiStyle defaultStyle;
  final SkinTone defaultSkinTone;
  final double height;
  final Color? backgroundColor;
  final TextStyle? categoryTextStyle;
  final bool showSearch;
  final bool showStyleSelector;
  final String searchHintText;
  final bool isSheet;
  final TextStyle? textStyle;

  const FluentEmojiPicker({
    super.key,
    this.onEmojiSelected,
    this.defaultStyle = EmojiStyle.threeDimensional,
    this.defaultSkinTone = SkinTone.defaultTone,
    this.height = 400,
    this.backgroundColor,
    this.categoryTextStyle,
    this.showSearch = false,
    this.showStyleSelector = false,
    this.searchHintText = 'Search emojis...',
    this.isSheet = true,
    this.textStyle,
  });

  @override
  State<FluentEmojiPicker> createState() => _FluentEmojiPickerState();

  /// Show the emoji picker as a bottom sheet
  static Future<EmojiData?> showEmojiBottomSheet({
    required BuildContext context,
    EmojiStyle defaultStyle = EmojiStyle.threeDimensional,
    SkinTone defaultSkinTone = SkinTone.defaultTone,
    double height = 400,
    Color? backgroundColor,
    TextStyle? categoryTextStyle,
    bool showSearch = false,
    bool showStyleSelector = false,
    String searchHintText = 'Search emojis...',
  }) async {
    return showModalBottomSheet<EmojiData>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FluentEmojiPicker(
        defaultStyle: defaultStyle,
        defaultSkinTone: defaultSkinTone,
        height: height,
        backgroundColor: backgroundColor,
        categoryTextStyle: categoryTextStyle,
        showSearch: showSearch,
        showStyleSelector: showStyleSelector,
        searchHintText: searchHintText,
        onEmojiSelected: (emoji) => Navigator.pop(context, emoji),
      ),
    );
  }

  /// Clean up resources - call this when your app is disposed
  static void disposeResources() {
    _HttpClient.dispose();
    _EmojiCacheManager().clearAllCaches();
  }
}

// Global cache manager for persistent storage across widget lifecycles
class _EmojiCacheManager {
  static final _EmojiCacheManager _instance = _EmojiCacheManager._internal();
  factory _EmojiCacheManager() => _instance;
  _EmojiCacheManager._internal();

  // Persistent caches that survive widget disposal
  final Map<String, List<EmojiData>> _categoryDataCache = {};
  final Map<String, bool> _categoryFullyLoaded = {};
  final Map<String, Map<String, Uint8List>> _imageCache = {};
  final Set<String> _loadingCategories = {};

  // Getters for cache access
  Map<String, List<EmojiData>> get categoryDataCache => _categoryDataCache;
  Map<String, bool> get categoryFullyLoaded => _categoryFullyLoaded;
  Map<String, Map<String, Uint8List>> get imageCache => _imageCache;
  Set<String> get loadingCategories => _loadingCategories;

  // Clear all caches (useful for style changes)
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

  bool isCategoryFullyLoaded(String category) {
    return _categoryFullyLoaded[category] == true;
  }

  void markCategoryAsLoaded(String category) {
    _categoryFullyLoaded[category] = true;
  }

  void markCategoryAsLoading(String category) {
    _loadingCategories.add(category);
  }

  void markCategoryAsNotLoading(String category) {
    _loadingCategories.remove(category);
  }

  List<EmojiData> getCategoryEmojis(String category) {
    return _categoryDataCache[category] ?? [];
  }

  void setCategoryEmojis(String category, List<EmojiData> emojis) {
    _categoryDataCache[category] = emojis;
  }

  Map<String, Uint8List> getCategoryImageCache(String category) {
    if (!_imageCache.containsKey(category)) {
      _imageCache[category] = {};
    }
    return _imageCache[category]!;
  }
}

class _FluentEmojiPickerState extends State<FluentEmojiPicker>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<String> _categories = [];
  List<EmojiData> _searchResults = [];
  bool _isInitialLoading = true;
  bool _isSearching = false;
  EmojiStyle _selectedStyle = EmojiStyle.threeDimensional;
  EmojiData? _showingSkinTonesFor;
  Offset? _skinToneTapLocalPosition;

  // Add this to track widget rebuild state
  int _rebuildCounter = 0;

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.defaultStyle;
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    // Don't dispose HTTP client as it's shared across instances
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      await EmojiService.getEmojis();
      final categories = await EmojiService.getCategories();

      setState(() {
        _categories = categories;
      });

      _tabController = TabController(length: _categories.length, vsync: this);
      _tabController.addListener(_onTabChanged);

      // Load first category completely
      if (categories.isNotEmpty) {
        await _loadCategoryCompletely(categories.first);
      }

      setState(() {
        _isInitialLoading = false;
      });

      // Preload adjacent categories in background
      _preloadAdjacentCategories();
    } catch (e) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    final newIndex = _tabController.index;
    if (newIndex < _categories.length) {
      final category = _categories[newIndex];

      // Load category completely if not ready
      if (!_isCategoryFullyLoaded(category)) {
        _loadCategoryCompletely(category);
      }

      // Preload adjacent categories
      _preloadAdjacentCategories();

      // Force rebuild to update the UI
      setState(() {
        _rebuildCounter++;
      });
    }
  }

  bool _isCategoryFullyLoaded(String category) {
    return _cacheManager.isCategoryFullyLoaded(category);
  }

  Future<void> _loadCategoryCompletely(String category) async {
    if (_cacheManager.loadingCategories.contains(category) ||
        _isCategoryFullyLoaded(category)) {
      return;
    }

    _cacheManager.markCategoryAsLoading(category);

    try {
      // Update UI to show loading for current category
      if (_categories.isNotEmpty &&
          _categories[_tabController.index] == category) {
        setState(() {
          _rebuildCounter++;
        });
      }

      // Step 1: Load emoji data
      List<EmojiData> emojis;
      if (_cacheManager.categoryDataCache.containsKey(category)) {
        emojis = _cacheManager.getCategoryEmojis(category);
        // debugPrint('Using cached emoji data for category: $category');
      } else {
        // debugPrint('Fetching emoji data for category: $category');
        emojis = await EmojiService.getEmojisByCategory(category);
        _cacheManager.setCategoryEmojis(category, emojis);
      }

      // Step 2: Pre-load all images for this category
      await _preloadCategoryImages(category, emojis);

      // Mark as fully loaded
      _cacheManager.markCategoryAsLoaded(category);

      // Update UI to show the category
      if (mounted &&
          _categories.isNotEmpty &&
          _categories[_tabController.index] == category) {
        setState(() {
          _rebuildCounter++;
        });
      }
    } catch (e) {
      // debugPrint('Error loading category $category: $e');
      // Mark as loaded with empty data to prevent infinite loading
      _cacheManager.setCategoryEmojis(category, []);
      _cacheManager.markCategoryAsLoaded(category);

      if (mounted &&
          _categories.isNotEmpty &&
          _categories[_tabController.index] == category) {
        setState(() {
          _rebuildCounter++;
        });
      }
    } finally {
      _cacheManager.markCategoryAsNotLoading(category);
    }
  }

  Future<void> _preloadCategoryImages(
    String category,
    List<EmojiData> emojis,
  ) async {
    final categoryImages = _cacheManager.getCategoryImageCache(category);
    final imagesToLoad = <String>[];

    for (final emoji in emojis) {
      if (emoji.isSkintoneBased) {
        // Preload every skin tone variant
        for (final skin in SkinTone.values) {
          final imageUrl = EmojiService.getEmojiImageUrl(
            emoji,
            style: _selectedStyle,
            skinTone: skin,
          );
          if (imageUrl.isNotEmpty && !categoryImages.containsKey(imageUrl)) {
            imagesToLoad.add(imageUrl);
          }
        }
      } else {
        final imageUrl = EmojiService.getEmojiImageUrl(
          emoji,
          style: _selectedStyle,
          skinTone: SkinTone.defaultTone,
        );
        if (imageUrl.isNotEmpty && !categoryImages.containsKey(imageUrl)) {
          imagesToLoad.add(imageUrl);
        }
      }
    }

    if (imagesToLoad.isEmpty) {
      // debugPrint('All images already cached for category: $category');
      return;
    }

    // debugPrint('Loading ${imagesToLoad.length} images for category: $category');

    const batchSize = 100;

    for (int i = 0; i < imagesToLoad.length; i += batchSize) {
      final batch = imagesToLoad.skip(i).take(batchSize).toList();

      try {
        await _loadImageBatch(category, batch).timeout(
          const Duration(milliseconds: 100),
          onTimeout: () {
            // debugPrint(
            //   'Batch timeout for category: $category, batch: ${i ~/ batchSize + 1}',
            // );
            // Mark remaining images as failed to prevent hanging
            for (final imageUrl in batch) {
              if (!categoryImages.containsKey(imageUrl)) {
                categoryImages[imageUrl] = Uint8List(0);
              }
            }
          },
        );
      } catch (e) {
        // debugPrint('Batch error for category: $category, error: $e');
        // Mark batch images as failed
        for (final imageUrl in batch) {
          categoryImages[imageUrl] = Uint8List(0);
        }
      }

      // Small delay between batches
      if (i + batchSize < imagesToLoad.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // debugPrint('Finished loading images for category: $category');
  }

  Future<void> _loadImageBatch(String category, List<String> imageUrls) async {
    final categoryImages = _cacheManager.getCategoryImageCache(category);

    final futures = imageUrls.map((imageUrl) async {
      try {
        // debugPrint('Loading image: $imageUrl');
        final response = await _httpClient.get(Uri.parse(imageUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          categoryImages[imageUrl] = response.bodyBytes;
          // debugPrint('Successfully loaded image: $imageUrl');
        } else {
          // debugPrint(
          //   'Failed to load image (status ${response.statusCode}): $imageUrl',
          // );
          categoryImages[imageUrl] = Uint8List(0);
        }
      } catch (e) {
        // debugPrint('Error loading image $imageUrl: $e');
        categoryImages[imageUrl] = Uint8List(0);
      }
    });

    await Future.wait(futures, eagerError: false);
  }

  // HTTP client instance (now persistent across widget lifecycles)
  late final _httpClient = _HttpClient();

  void _preloadAdjacentCategories() {
    if (_categories.isEmpty) return;

    final currentIndex = _tabController.index;

    // Preload next and previous categories
    for (int i = -1; i <= 1; i++) {
      final index = currentIndex + i;
      if (index >= 0 && index < _categories.length && index != currentIndex) {
        final category = _categories[index];
        if (!_isCategoryFullyLoaded(category) &&
            !_cacheManager.loadingCategories.contains(category)) {
          // Load in background without await
          _loadCategoryCompletely(category);
        }
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    } else {
      setState(() {
        _isSearching = true;
      });
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    final results = await EmojiService.searchEmojis(query);
    if (_searchController.text == query && mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _onEmojiTap(EmojiData emoji, Offset? globalPosition) {
    if (emoji.isSkintoneBased && emoji.skintones != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        final local = box?.globalToLocal(globalPosition!);
        setState(() {
          _showingSkinTonesFor = emoji;
          _skinToneTapLocalPosition = local;
        });
      } catch (e) {
        // debugPrint('Error getting local position for emoji $emoji: $e');
      }
    } else {
      widget.onEmojiSelected?.call(emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (!widget.isSheet) {
      return SizedBox(
        // height: widget.height,
        child: Column(
          children: [
            TabBar(
              padding: EdgeInsets.zero,
              dividerColor: Colors.black,
              unselectedLabelStyle: widget.textStyle,
              controller: _tabController,
              labelColor: Colors.black,
              isScrollable: true,
              tabs: _categories.map((category) => Tab(text: category)).toList(),
              labelStyle: widget.categoryTextStyle,
              indicatorColor: Colors.black,
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
            ),
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildTabBarView(),
            ),
          ],
        ),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color:
            widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Search bar
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHintText,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // Style selector
          if (!_isSearching && widget.showStyleSelector) _buildStyleSelector(),

          // Category tabs
          if (!_isSearching && _categories.isNotEmpty)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _categories.map((category) => Tab(text: category)).toList(),
              labelStyle: widget.categoryTextStyle,
            ),

          // Emoji content
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildTabBarView(),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<EmojiStyle>(
        value: _selectedStyle,
        decoration: const InputDecoration(
          labelText: 'Style',
          border: OutlineInputBorder(),
        ),
        items: EmojiStyle.values
            .map(
              (style) =>
                  DropdownMenuItem(value: style, child: Text(style.value)),
            )
            .toList(),
        onChanged: (style) {
          setState(() {
            _selectedStyle = style!;
            // Clear caches for style change but keep category data
            _cacheManager.clearCachesForStyleChange();
            _rebuildCounter++;
          });

          // Reload current category with new style
          if (_categories.isNotEmpty) {
            final currentCategory = _categories[_tabController.index];
            _loadCategoryCompletely(currentCategory);
            _preloadAdjacentCategories();
          }
        },
      ),
    );
  }

  Widget _buildTabBarView() {
    if (_categories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _categories
          .map(
            (category) => CategoryPage(
              // Fixed key that includes all necessary state
              key: ValueKey(
                '$category-${_selectedStyle.value}-${_isCategoryFullyLoaded(category)}-$_rebuildCounter',
              ),
              category: category,
              emojis: _cacheManager.getCategoryEmojis(category),
              isFullyLoaded: _isCategoryFullyLoaded(category),
              selectedStyle: _selectedStyle,
              imageCache: _cacheManager.getCategoryImageCache(category),
              showingSkinTonesFor: _showingSkinTonesFor,
              onEmojiTap: _onEmojiTap,
              onCloseSkinTones: () =>
                  setState(() => _showingSkinTonesFor = null),
              onEmojiSelected: widget.onEmojiSelected,
              skinToneTapLocalPosition: _skinToneTapLocalPosition,
            ),
          )
          .toList(),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No emojis found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // For search results, show immediately without caching
    return CategoryPage(
      key: ValueKey('search-${_selectedStyle.value}'),
      category: 'Search Results',
      emojis: _searchResults,
      isFullyLoaded: true,
      selectedStyle: _selectedStyle,
      imageCache: const {}, // No cache for search results
      showingSkinTonesFor: _showingSkinTonesFor,
      onEmojiTap: _onEmojiTap,
      onCloseSkinTones: () => setState(() => _showingSkinTonesFor = null),
      onEmojiSelected: widget.onEmojiSelected,
      skinToneTapLocalPosition: _skinToneTapLocalPosition,
    );
  }
}

// Category page that shows single loading spinner until fully loaded
class CategoryPage extends StatelessWidget {
  final String category;
  final List<EmojiData> emojis;
  final bool isFullyLoaded;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final EmojiData? showingSkinTonesFor;
  final Function(EmojiData, Offset?) onEmojiTap;
  final VoidCallback onCloseSkinTones;
  final Function(EmojiData)? onEmojiSelected;
  final Offset? skinToneTapLocalPosition;

  const CategoryPage({
    required this.category,
    required this.emojis,
    required this.isFullyLoaded,
    required this.selectedStyle,
    required this.imageCache,
    required this.showingSkinTonesFor,
    required this.onEmojiTap,
    required this.onCloseSkinTones,
    required this.onEmojiSelected,
    required this.skinToneTapLocalPosition,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Show single loading spinner until category is fully loaded
    if (!isFullyLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (emojis.isEmpty) {
      return const Center(
        child: Text(
          'No emojis in this category',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        EmojiGrid(
          emojis: emojis,
          selectedStyle: selectedStyle,
          imageCache: imageCache,
          onEmojiTap: onEmojiTap,
        ),
        if (showingSkinTonesFor != null)
          SkinToneOverlay(
            emoji: showingSkinTonesFor!,
            selectedStyle: selectedStyle,
            imageCache: imageCache,
            onClose: onCloseSkinTones,
            onEmojiSelected: onEmojiSelected,
            tapLocalPosition: skinToneTapLocalPosition,
          ),
      ],
    );
  }
}

// Fast emoji grid using cached images
class EmojiGrid extends StatelessWidget {
  final List<EmojiData> emojis;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final Function(EmojiData, Offset?) onEmojiTap;

  const EmojiGrid({
    required this.emojis,
    required this.selectedStyle,
    required this.imageCache,
    required this.onEmojiTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return EmojiItem(
          key: ValueKey('${emojis[index].cldr}-${selectedStyle.value}'),
          emoji: emojis[index],
          selectedStyle: selectedStyle,
          imageCache: imageCache,
          onTap: onEmojiTap,
        );
      },
    );
  }
}

// Fast emoji item using cached image bytes
class EmojiItem extends StatelessWidget {
  final EmojiData emoji;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final Function(EmojiData, Offset?) onTap;

  const EmojiItem({
    required this.emoji,
    required this.selectedStyle,
    required this.imageCache,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) => onTap(emoji, details.globalPosition),
      // Fallback: if gesture system doesn't call onTapUp for some reason,
      // still call without position on onTap (keeps behavior robust)
      onTap: () => onTap(emoji, null),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).hoverColor,
        ),
        child: Stack(
          children: [
            Center(
              child: EmojiImage(
                emoji: emoji,
                selectedStyle: selectedStyle,
                imageCache: imageCache,
                size: 32,
              ),
            ),
            if (emoji.isSkintoneBased)
              Positioned(right: 0, bottom: 0, child: BottomRightHalfSquare()),
          ],
        ),
      ),
    );
  }
}

class BottomRightHalfSquare extends StatelessWidget {
  final double size;
  final Color color;

  const BottomRightHalfSquare({
    super.key,
    this.size = 12,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipPath(
      clipper: _BottomRightHalfSquareClipper(),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(color: color),
      ),
    );
    return child;
  }
}

class _BottomRightHalfSquareClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Triangle = bottom-right half of the square (diagonal from top-left -> bottom-right)
    final path = Path()
      ..moveTo(size.width, 0) // top-right
      ..lineTo(size.width, size.height) // bottom-right
      ..lineTo(0, size.height) // bottom-left
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Ultra-fast emoji image using cached bytes
class EmojiImage extends StatelessWidget {
  final EmojiData emoji;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final double size;
  final SkinTone? skinTone;

  const EmojiImage({
    super.key,
    required this.emoji,
    required this.selectedStyle,
    required this.imageCache,
    required this.size,
    this.skinTone,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = EmojiService.getEmojiImageUrl(
      emoji,
      style: selectedStyle,
      skinTone: skinTone ?? SkinTone.defaultTone,
    );

    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.emoji_emotions, size: size * 0.5),
      );
    }

    // Get cached image bytes
    final cachedBytes = imageCache[imageUrl];

    if (cachedBytes == null || cachedBytes.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.broken_image, size: size * 0.5),
      );
    }

    // Display cached image instantly
    return Image.memory(
      cachedBytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.broken_image, size: size * 0.5),
      ),
    );
  }
}

// Skin tone overlay with cached images
class SkinToneOverlay extends StatelessWidget {
  final EmojiData emoji;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final VoidCallback onClose;
  final Function(EmojiData)? onEmojiSelected;
  final Offset? tapLocalPosition;

  const SkinToneOverlay({
    required this.emoji,
    required this.selectedStyle,
    required this.imageCache,
    required this.onClose,
    required this.onEmojiSelected,
    required this.tapLocalPosition,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Popup visual measurements
    final double itemSize = 24;
    final double itemPadding = 12; // horizontal padding around each tone
    final int toneCount = SkinTone.values.length;
    final double popupWidth =
        (itemSize + itemPadding) * toneCount + 16; // add some margin
    const double popupHeight = 56;

    final media = MediaQuery.of(context).size;
    // If no tap position available, fallback to bottom center behavior
    final Offset pos =
        tapLocalPosition ?? Offset(media.width / 2, media.height);

    // Center the popup horizontally on the tap, clamp to screen edges
    double left = pos.dx - popupWidth / 2;
    left = left.clamp(8.0, media.width - popupWidth - 8.0);

    // Prefer showing popup above the tap; if not enough space, show below
    double top = pos.dy - popupHeight - 12;
    if (top < 8) {
      top = pos.dy + 12;
    }

    return Positioned(
      left: left,
      top: top,
      width: popupWidth,
      height: popupHeight,
      child: GestureDetector(
        onTap: () {}, // absorb taps so outer GestureDetector won't close
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: SkinTone.values.map((skinTone) {
                  return GestureDetector(
                    onTap: () {
                      final emojiWithSkinTone = emoji.copyWith(
                        selectedSkinTone: skinTone,
                      );
                      onEmojiSelected?.call(emojiWithSkinTone);
                      onClose();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: EmojiImage(
                        emoji: emoji,
                        selectedStyle: selectedStyle,
                        imageCache: imageCache,
                        size: itemSize,
                        skinTone: skinTone,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// HTTP client implementation with singleton pattern
class _HttpClient {
  static http.Client? _client;

  static http.Client get client {
    _client ??= http.Client();
    return _client!;
  }

  Future<_HttpResponse> get(Uri uri) async {
    try {
      final response = await client.get(uri);
      return _HttpResponse(response.statusCode, response.bodyBytes);
    } catch (e) {
      // debugPrint('HTTP error for ${uri.toString()}: $e');
      // If client is closed, create a new one and retry
      if (e.toString().contains('Client is already closed')) {
        _client = http.Client();
        final response = await client.get(uri);
        return _HttpResponse(response.statusCode, response.bodyBytes);
      }
      rethrow;
    }
  }

  static void dispose() {
    _client?.close();
    _client = null;
  }
}

class _HttpResponse {
  final int statusCode;
  final Uint8List bodyBytes;

  _HttpResponse(this.statusCode, this.bodyBytes);
}
