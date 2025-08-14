import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fluent_emoji/src/services/emoji_cache_manager.dart';
import 'package:http/http.dart' as http;

import 'models/emoji_data.dart';
import 'services/emoji_service.dart';

final _emojiCacheManager = EmojiCacheManager();

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
  final bool isScrollable;

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
    this.isScrollable = false,
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
    EmojiCacheManager().clearAllCaches();
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
  late final _httpClient = _HttpClient();

  // Create a map to store individual scroll controllers for each category
  final Map<String, ScrollController> _scrollControllers = {};
  ScrollController? _searchScrollController;

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.defaultStyle;
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
    _searchScrollController = ScrollController();
    _searchScrollController!.addListener(_onGridScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchScrollController?.dispose();

    // Dispose all category scroll controllers
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _scrollControllers.clear();

    super.dispose();
  }

  // Get or create a scroll controller for a specific category
  ScrollController _getScrollControllerForCategory(String category) {
    if (!_scrollControllers.containsKey(category)) {
      final controller = ScrollController();
      controller.addListener(_onGridScroll);
      _scrollControllers[category] = controller;
    }
    return _scrollControllers[category]!;
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
    if (_showingSkinTonesFor != null) {
      setState(() {
        _showingSkinTonesFor = null;
      });
    }
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
    }
  }

  bool _isCategoryFullyLoaded(String category) {
    return _emojiCacheManager.isCategoryFullyLoaded(category, _selectedStyle);
  }

  Future<void> _loadCategoryCompletely(String category) async {
    if (_emojiCacheManager.isCategoryLoading(category, _selectedStyle) ||
        _isCategoryFullyLoaded(category)) {
      return;
    }

    _emojiCacheManager.markCategoryAsLoading(category, _selectedStyle);

    try {
      // Step 1: Load emoji data (this might be shared across styles)
      List<EmojiData> emojis;
      final cachedEmojis = _emojiCacheManager.getCategoryEmojis(
        category,
        _selectedStyle,
      );
      if (cachedEmojis.isNotEmpty) {
        emojis = cachedEmojis;
      } else {
        emojis = await EmojiService.getEmojisByCategory(
          category,
          _selectedStyle,
        );
        _emojiCacheManager.setCategoryEmojis(category, _selectedStyle, emojis);
      }

      // Step 2: Pre-load all images for this category and style
      await _preloadCategoryImages(category, emojis);

      // Mark as fully loaded for this specific style
      _emojiCacheManager.markCategoryAsLoaded(category, _selectedStyle);

      // Update UI to show the category
      if (mounted &&
          _categories.isNotEmpty &&
          _categories[_tabController.index] == category) {
        setState(() {});
      }
    } catch (e) {
      // Mark as loaded with empty data to prevent infinite loading
      _emojiCacheManager.setCategoryEmojis(category, _selectedStyle, []);
      _emojiCacheManager.markCategoryAsLoaded(category, _selectedStyle);
    } finally {
      _emojiCacheManager.markCategoryAsNotLoading(category, _selectedStyle);
      if (mounted) setState(() {});
    }
  }

  Future<void> _preloadCategoryImages(
    String category,
    List<EmojiData> emojis, {
    bool preloadSkinTones = false,
  }) async {
    final categoryImages = _emojiCacheManager.getCategoryImageCache(
      category,
      _selectedStyle,
    );
    final imagesToLoad = <String>[];

    for (final emoji in emojis) {
      if (preloadSkinTones && emoji.isSkintoneBased) {
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
      return;
    }

    final batchSize = _selectedStyle == EmojiStyle.animated ? 5 : 100;

    for (int i = 0; i < imagesToLoad.length; i += batchSize) {
      final batch = imagesToLoad.skip(i).take(batchSize).toList();

      try {
        await _loadImageBatch(category, batch);
      } catch (e) {
        debugPrint('Batch error for category: $category, error: $e');
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

    // debugPrint(
    //   'Finished loading images for category: $category, style: ${_selectedStyle.value}',
    // );
  }

  Future<void> _preloadSkinTonesForEmoji(
    String category,
    EmojiData emoji,
  ) async {
    if (!emoji.isSkintoneBased || emoji.skintones == null) return;

    final categoryImages = _emojiCacheManager.getCategoryImageCache(
      category,
      _selectedStyle,
    );
    final imagesToLoad = <String>[];

    // Load all skin tone variants for this specific emoji
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

    if (imagesToLoad.isEmpty) return;

    // Load skin tone images quickly
    final futures = imagesToLoad.map((imageUrl) async {
      try {
        final response = await _httpClient.get(Uri.parse(imageUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          categoryImages[imageUrl] = response.bodyBytes;
        } else {
          categoryImages[imageUrl] = Uint8List(0);
        }
      } catch (e) {
        categoryImages[imageUrl] = Uint8List(0);
      }
    });

    await Future.wait(futures, eagerError: false);
    setState(() {});
  }

  Future<void> _loadImageBatch(String category, List<String> imageUrls) async {
    final categoryImages = _emojiCacheManager.getCategoryImageCache(
      category,
      _selectedStyle,
    );

    final futures = imageUrls.map((imageUrl) async {
      try {
        final response = await _httpClient.get(Uri.parse(imageUrl));
        // .timeout(
        //   Duration(seconds: _selectedStyle == EmojiStyle.animated ? 10 : 3),
        //   onTimeout: () {
        //     debugPrint(
        //       'Image load timeout for: $imageUrl, category: $category, style: ${_selectedStyle.value}',
        //     );
        //     return _HttpResponse(408, Uint8List(0));
        //   },
        // );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          categoryImages[imageUrl] = response.bodyBytes;
        } else {
          categoryImages[imageUrl] = Uint8List(0);
        }
      } catch (e) {
        categoryImages[imageUrl] = Uint8List(0);
      }
    });

    await Future.wait(futures, eagerError: false);
  }

  void _preloadAdjacentCategories() {
    if (_categories.isEmpty) return;

    final currentIndex = _tabController.index;

    // Preload next and previous categories for current style
    for (int i = -1; i <= 1; i++) {
      final index = currentIndex + i;
      if (index >= 0 && index < _categories.length && index != currentIndex) {
        final category = _categories[index];
        if (!_isCategoryFullyLoaded(category) &&
            !_emojiCacheManager.isCategoryLoading(category, _selectedStyle)) {
          // Load in background without await
          _loadCategoryCompletely(category);
        }
      }
    }
  }

  void _onGridScroll() {
    if (_showingSkinTonesFor != null) {
      // Hide skin tone picker when scrolling
      setState(() {
        _showingSkinTonesFor = null;
      });
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

  // Updated _onEmojiTap method to ensure cache keys are set
  void _onEmojiTap(EmojiData emoji, Offset? globalPosition) {
    if (emoji.isSkintoneBased && emoji.skintones != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        final local = box?.globalToLocal(globalPosition!);

        // Ensure emoji has cache key when showing skin tones
        final emojiWithCacheKey = emoji.withCacheKey(_selectedStyle);

        setState(() {
          _showingSkinTonesFor = emojiWithCacheKey;
          _skinToneTapLocalPosition = local;
        });

        // Preload skin tones for this emoji when overlay is shown
        final currentCategory = _categories.isNotEmpty
            ? _categories[_tabController.index]
            : '';
        if (currentCategory.isNotEmpty) {
          _preloadSkinTonesForEmoji(currentCategory, emojiWithCacheKey);
        }
      } catch (e) {
        // debugPrint('Error getting local position for emoji $emoji: $e');
      }
    } else {
      // Ensure emoji has cache key before calling onEmojiSelected
      final emojiWithCacheKey = emoji.withCacheKey(
        _selectedStyle,
        emoji.selectedSkinTone ?? SkinTone.defaultTone,
      );
      widget.onEmojiSelected?.call(emojiWithCacheKey);
    }
  }

  // Helper method to get combined image cache for search
  Map<String, Uint8List> _getCombinedImageCache() {
    final combinedCache = <String, Uint8List>{};
    for (final category in _categories) {
      final categoryCache = _emojiCacheManager.getCategoryImageCache(
        category,
        _selectedStyle,
      );
      combinedCache.addAll(categoryCache);
    }
    return combinedCache;
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

    final searchBar = Padding(
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
        ),
      ),
    );

    final tabBar = TabBar(
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
    );

    final contentView = Expanded(
      child: _isSearching ? _buildSearchResults() : _buildTabBarView(),
    );

    if (!widget.isSheet) {
      return Column(
        children: [
          // Search bar
          if (widget.showSearch) searchBar,
          // Category tabs
          if (!_isSearching && _categories.isNotEmpty) tabBar,
          contentView,
        ],
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
          if (widget.showSearch) searchBar,

          // Style selector
          if (!_isSearching && widget.showStyleSelector) _buildStyleSelector(),

          // Category tabs
          if (!_isSearching && _categories.isNotEmpty) tabBar,

          // Emoji content
          contentView,
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
          final previousStyle = _selectedStyle;
          setState(() {
            _selectedStyle = style!;
            // Only clear image caches for style change, not emoji data
            _emojiCacheManager.clearCachesForStyleChange();
          });

          // Reload current category with new style
          if (_categories.isNotEmpty) {
            final currentCategory = _categories[_tabController.index];
            _loadCategoryCompletely(currentCategory);
            _preloadAdjacentCategories();
          }

          debugPrint(
            'Style changed from ${previousStyle.value} to ${style!.value}',
          );
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
      physics: widget.isScrollable
          ? null
          : const NeverScrollableScrollPhysics(),
      children: _categories
          .map(
            (category) => CategoryPage(
              key: ValueKey('$category-${_selectedStyle.value}'),
              category: category,
              emojis: _emojiCacheManager.getCategoryEmojis(
                category,
                _selectedStyle,
              ),
              isFullyLoaded: _isCategoryFullyLoaded(category),
              selectedStyle: _selectedStyle,
              imageCache: _emojiCacheManager.getCategoryImageCache(
                category,
                _selectedStyle,
              ),
              showingSkinTonesFor: _showingSkinTonesFor,
              onEmojiTap: _onEmojiTap,
              onCloseSkinTones: () =>
                  setState(() => _showingSkinTonesFor = null),
              onEmojiSelected: (emoji) {
                // Ensure the selected emoji has proper cache key
                final emojiWithCacheKey = emoji.withCacheKey(
                  _selectedStyle,
                  emoji.selectedSkinTone ?? SkinTone.defaultTone,
                );
                widget.onEmojiSelected?.call(emojiWithCacheKey);
              },
              skinToneTapLocalPosition: _skinToneTapLocalPosition,
              gridController: _getScrollControllerForCategory(category),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return SearchResultsGrid(
      key: const ValueKey(
        'search-results-grid',
      ), // Stable key to prevent rebuilds
      emojis: _searchResults,
      selectedStyle: _selectedStyle,
      imageCache: _getCombinedImageCache(),
      showingSkinTonesFor: _showingSkinTonesFor,
      onEmojiTap: _onEmojiTap,
      onCloseSkinTones: () => setState(() => _showingSkinTonesFor = null),
      onEmojiSelected: (emoji) {
        // Ensure the selected emoji has proper cache key
        final emojiWithCacheKey = emoji.withCacheKey(
          _selectedStyle,
          emoji.selectedSkinTone ?? SkinTone.defaultTone,
        );
        widget.onEmojiSelected?.call(emojiWithCacheKey);
      },
      skinToneTapLocalPosition: _skinToneTapLocalPosition,
      gridController: _searchScrollController!,
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
  final ScrollController gridController;

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
    required this.gridController,
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
          controller: gridController,
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

// Search results grid with emoji persistence to prevent flickering
class SearchResultsGrid extends StatefulWidget {
  final List<EmojiData> emojis;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final EmojiData? showingSkinTonesFor;
  final Function(EmojiData, Offset?) onEmojiTap;
  final VoidCallback onCloseSkinTones;
  final Function(EmojiData)? onEmojiSelected;
  final Offset? skinToneTapLocalPosition;
  final ScrollController gridController;

  const SearchResultsGrid({
    required this.emojis,
    required this.selectedStyle,
    required this.imageCache,
    required this.showingSkinTonesFor,
    required this.onEmojiTap,
    required this.onCloseSkinTones,
    required this.onEmojiSelected,
    required this.skinToneTapLocalPosition,
    required this.gridController,
    super.key,
  });

  @override
  State<SearchResultsGrid> createState() => _SearchResultsGridState();
}

class _SearchResultsGridState extends State<SearchResultsGrid> {
  // Keep track of displayed emojis with stable keys
  final Map<String, EmojiData> _displayedEmojis = {};
  final Map<String, Widget> _emojiWidgets = {};

  @override
  Widget build(BuildContext context) {
    // Update displayed emojis, keeping existing ones stable
    final currentEmojiKeys = widget.emojis.map((e) => e.cldr).toSet();

    // Remove emojis that are no longer in search results
    _displayedEmojis.removeWhere(
      (key, value) => !currentEmojiKeys.contains(key),
    );
    _emojiWidgets.removeWhere((key, value) => !currentEmojiKeys.contains(key));

    // Add new emojis
    for (final emoji in widget.emojis) {
      if (!_displayedEmojis.containsKey(emoji.cldr)) {
        _displayedEmojis[emoji.cldr] = emoji;
        _emojiWidgets[emoji.cldr] = EmojiItem(
          key: ValueKey('search-${emoji.cldr}-${widget.selectedStyle.value}'),
          emoji: emoji,
          selectedStyle: widget.selectedStyle,
          imageCache: widget.imageCache,
          onTap: widget.onEmojiTap,
        );
      }
    }

    return Stack(
      children: [
        GridView.builder(
          controller: widget.gridController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: widget.emojis.length,
          itemBuilder: (context, index) {
            final emoji = widget.emojis[index];
            // Return the stable widget instance to prevent flickering
            return _emojiWidgets[emoji.cldr] ?? const SizedBox.shrink();
          },
        ),
        if (widget.showingSkinTonesFor != null)
          SkinToneOverlay(
            emoji: widget.showingSkinTonesFor!,
            selectedStyle: widget.selectedStyle,
            imageCache: widget.imageCache,
            onClose: widget.onCloseSkinTones,
            onEmojiSelected: widget.onEmojiSelected,
            tapLocalPosition: widget.skinToneTapLocalPosition,
          ),
      ],
    );
  }
}

class EmojiGrid extends StatelessWidget {
  final List<EmojiData> emojis;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final Function(EmojiData, Offset?) onEmojiTap;
  final ScrollController controller;

  const EmojiGrid({
    required this.emojis,
    required this.selectedStyle,
    required this.imageCache,
    required this.onEmojiTap,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return EmojiItem(
          key: ValueKey('${emojis[index].cldr}-${selectedStyle.value}-$index'),
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
class EmojiItem extends StatefulWidget {
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
  State<EmojiItem> createState() => _EmojiItemState();
}

class _EmojiItemState extends State<EmojiItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) => widget.onTap(widget.emoji, details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).hoverColor,
        ),
        child: Stack(
          children: [
            Center(
              child: EmojiImage(
                emoji: widget.emoji,
                selectedStyle: widget.selectedStyle,
                imageCache: widget.imageCache,
                size: 32,
              ),
            ),
            if (widget.emoji.isSkintoneBased)
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

// Ultra-fast emoji image using cached bytes with proper disposal handling
class EmojiImage extends StatefulWidget {
  final EmojiData emoji;
  final EmojiStyle selectedStyle;
  final Map<String, Uint8List> imageCache;
  final double size;
  final SkinTone? skinTone;
  final VoidCallback? onError;

  const EmojiImage({
    super.key,
    required this.emoji,
    required this.selectedStyle,
    required this.imageCache,
    required this.size,
    this.onError,
    this.skinTone,
  });

  @override
  State<EmojiImage> createState() => _EmojiImageState();
}

class _EmojiImageState extends State<EmojiImage> {
  String? _currentImageUrl;
  bool _isLoading = false;
  Image? _cachedImageWidget;

  @override
  Widget build(BuildContext context) {
    final imageUrl = EmojiService.getEmojiImageUrl(
      widget.emoji,
      style: widget.selectedStyle,
      skinTone: widget.skinTone ?? SkinTone.defaultTone,
    );

    if (imageUrl.isEmpty) {
      widget.onError?.call();
      return const SizedBox.shrink();
    }

    // Get cached image bytes
    final cachedBytes = widget.imageCache[imageUrl];

    if (cachedBytes == null || cachedBytes.isEmpty) {
      // If not in cache and not loading, try to load it (useful for search results)
      if (!_isLoading) {
        _loadImageOnDemand(imageUrl);
      }

      // Show loading or placeholder while loading
      return SizedBox(width: widget.size, height: widget.size);
    }

    // Only create new ExtendedImage if URL changed or widget is null
    if (_currentImageUrl != imageUrl || _cachedImageWidget == null) {
      _currentImageUrl = imageUrl;
      _cachedImageWidget = Image.memory(
        cachedBytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        // Use a stable key based on emoji and style only
        key: ValueKey(
          'emoji-img-${widget.emoji.cldr}-${widget.selectedStyle.value}-${widget.skinTone?.value ?? "default"}',
        ),
      );
    }

    return _cachedImageWidget!;
  }

  Future<void> _loadImageOnDemand(String imageUrl) async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final client = _HttpClient();
      final response = await client.get(Uri.parse(imageUrl));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Add to cache for future use
        widget.imageCache[imageUrl] = response.bodyBytes;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _cachedImageWidget = null; // Force recreation with new bytes
          });
        }
      } else {
        // Mark as failed
        widget.imageCache[imageUrl] = Uint8List(0);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          widget.onError?.call();
        }
      }
    } catch (e) {
      // Mark as failed
      widget.imageCache[imageUrl] = Uint8List(0);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        widget.onError?.call();
      }
    }
  }
}

// Skin tone overlay with cached images and proper disposal
class SkinToneOverlay extends StatefulWidget {
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
  State<SkinToneOverlay> createState() => _SkinToneOverlayState();
}

class _SkinToneOverlayState extends State<SkinToneOverlay> {
  bool isDisplaying = true;

  // Check if skin tone images are available
  bool _areSkinTonesLoaded() {
    for (final skinTone in SkinTone.values) {
      final imageUrl = EmojiService.getEmojiImageUrl(
        widget.emoji,
        style: widget.selectedStyle,
        skinTone: skinTone,
      );
      if (!widget.imageCache.containsKey(imageUrl)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!isDisplaying || !_areSkinTonesLoaded()) return const SizedBox.shrink();

    const double itemSize = 24;
    const double itemPadding = 12;
    final int toneCount = SkinTone.values.length;
    final double popupWidth = (itemSize + itemPadding) * toneCount + 16;
    const double popupHeight = 56;

    final media = MediaQuery.of(context).size;
    final Offset pos =
        widget.tapLocalPosition ?? Offset(media.width / 2, media.height);

    double left = pos.dx - popupWidth / 2;
    left = left.clamp(8.0, media.width - popupWidth - 8.0);

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
        onTap: () {},
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
                  color: Colors.black.withAlpha(38),
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
                      final emojiWithSkinTone = widget.emoji.copyWith(
                        selectedSkinTone: skinTone,
                      );
                      widget.onEmojiSelected?.call(emojiWithSkinTone);
                      widget.onClose();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: EmojiImage(
                        key: ValueKey(
                          'skintone-${widget.emoji.cldr}-${skinTone.value}',
                        ),
                        emoji: widget.emoji,
                        selectedStyle: widget.selectedStyle,
                        imageCache: widget.imageCache,
                        size: itemSize,
                        skinTone: skinTone,
                        onError: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                isDisplaying = false;
                              });
                            }
                          });
                        },
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
