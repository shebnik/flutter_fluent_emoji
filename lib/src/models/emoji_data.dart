class EmojiData {
  final String cldr;
  final String fromVersion;
  final String glyph;
  final List<String> glyphAsUtfInEmoticons;
  final String group;
  final List<String> keywords;
  final List<String> mappedToEmoticons;
  final String tts;
  final String unicode;
  final int sortOrder;
  final bool isSkintoneBased;
  final Map<String, String>? styles;
  final Map<String, Map<String, String>>? skintones;
  final SkinTone? selectedSkinTone; // Added for skin tone selection tracking

  const EmojiData({
    required this.cldr,
    required this.fromVersion,
    required this.glyph,
    required this.glyphAsUtfInEmoticons,
    required this.group,
    required this.keywords,
    required this.mappedToEmoticons,
    required this.tts,
    required this.unicode,
    required this.sortOrder,
    required this.isSkintoneBased,
    this.styles,
    this.skintones,
    this.selectedSkinTone,
  });

  factory EmojiData.fromJson(Map<String, dynamic> json) {
    return EmojiData(
      cldr: json['cldr'] ?? '',
      fromVersion: json['fromVersion'] ?? '',
      glyph: json['glyph'] ?? '',
      glyphAsUtfInEmoticons: List<String>.from(
        json['glyphAsUtfInEmoticons'] ?? [],
      ),
      group: json['group'] ?? '',
      keywords: List<String>.from(json['keywords'] ?? []),
      mappedToEmoticons: List<String>.from(json['mappedToEmoticons'] ?? []),
      tts: json['tts'] ?? '',
      unicode: json['unicode'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
      isSkintoneBased: json['isSkintoneBased'] ?? false,
      styles: json['styles'] != null
          ? Map<String, String>.from(json['styles'])
          : null,
      skintones: json['skintones'] != null
          ? Map<String, Map<String, String>>.from(
              json['skintones'].map(
                (key, value) => MapEntry(key, Map<String, String>.from(value)),
              ),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cldr': cldr,
      'fromVersion': fromVersion,
      'glyph': glyph,
      'glyphAsUtfInEmoticons': glyphAsUtfInEmoticons,
      'group': group,
      'keywords': keywords,
      'mappedToEmoticons': mappedToEmoticons,
      'tts': tts,
      'unicode': unicode,
      'sortOrder': sortOrder,
      'isSkintoneBased': isSkintoneBased,
      'styles': styles,
      'skintones': skintones,
    };
  }

  EmojiData copyWith({
    String? cldr,
    String? fromVersion,
    String? glyph,
    List<String>? glyphAsUtfInEmoticons,
    String? group,
    List<String>? keywords,
    List<String>? mappedToEmoticons,
    String? tts,
    String? unicode,
    int? sortOrder,
    bool? isSkintoneBased,
    Map<String, String>? styles,
    Map<String, Map<String, String>>? skintones,
    SkinTone? selectedSkinTone,
  }) {
    return EmojiData(
      cldr: cldr ?? this.cldr,
      fromVersion: fromVersion ?? this.fromVersion,
      glyph: glyph ?? this.glyph,
      glyphAsUtfInEmoticons:
          glyphAsUtfInEmoticons ?? this.glyphAsUtfInEmoticons,
      group: group ?? this.group,
      keywords: keywords ?? this.keywords,
      mappedToEmoticons: mappedToEmoticons ?? this.mappedToEmoticons,
      tts: tts ?? this.tts,
      unicode: unicode ?? this.unicode,
      sortOrder: sortOrder ?? this.sortOrder,
      isSkintoneBased: isSkintoneBased ?? this.isSkintoneBased,
      styles: styles ?? this.styles,
      skintones: skintones ?? this.skintones,
      selectedSkinTone: selectedSkinTone ?? this.selectedSkinTone,
    );
  }
}

enum EmojiStyle {
  threeDimensional('3D'),
  color('Color'),
  flat('Flat'),
  highContrast('HighContrast'),
  animated('Animated');

  const EmojiStyle(this.value);
  final String value;
}

enum SkinTone {
  defaultTone('Default'),
  light('Light'),
  mediumLight('MediumLight'),
  medium('Medium'),
  mediumDark('MediumDark'),
  dark('Dark');

  const SkinTone(this.value);
  final String value;
}
