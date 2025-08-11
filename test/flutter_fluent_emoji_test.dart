import 'package:flutter_fluent_emoji/flutter_fluent_emoji.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmojiData', () {
    test('should create EmojiData from JSON', () {
      final json = {
        'cldr': 'grinning face',
        'fromVersion': '1.0',
        'glyph': '😀',
        'glyphAsUtfInEmoticons': ['laugh'],
        'group': 'Smileys & Emotion',
        'keywords': ['face', 'grin', 'grinning face'],
        'mappedToEmoticons': ['1f603_grinningfacewithbigeyes'],
        'tts': 'grinning face',
        'unicode': '1f600',
        'sortOrder': 1,
        'isSkintoneBased': false,
        'styles': {
          '3D': 'https://example.com/3d.png',
          'Color': 'https://example.com/color.svg',
        },
      };

      final emoji = EmojiData.fromJson(json);

      expect(emoji.cldr, 'grinning face');
      expect(emoji.glyph, '😀');
      expect(emoji.group, 'Smileys & Emotion');
      expect(emoji.unicode, '1f600');
      expect(emoji.sortOrder, 1);
      expect(emoji.isSkintoneBased, false);
      expect(emoji.styles, isNotNull);
      expect(emoji.styles!['3D'], 'https://example.com/3d.png');
    });

    test('should handle missing optional fields', () {
      final json = {
        'cldr': 'test emoji',
        'fromVersion': '1.0',
        'glyph': '🎉',
        'glyphAsUtfInEmoticons': [],
        'group': 'Test',
        'keywords': [],
        'mappedToEmoticons': [],
        'tts': 'test',
        'unicode': '1f389',
        'sortOrder': 0,
        'isSkintoneBased': false,
      };

      final emoji = EmojiData.fromJson(json);

      expect(emoji.styles, isNull);
      expect(emoji.skintones, isNull);
    });
  });

  group('EmojiStyle', () {
    test('should have correct values', () {
      expect(EmojiStyle.threeDimensional.value, '3D');
      expect(EmojiStyle.color.value, 'Color');
      expect(EmojiStyle.flat.value, 'Flat');
      expect(EmojiStyle.highContrast.value, 'HighContrast');
      expect(EmojiStyle.animated.value, 'Animated');
    });
  });

  group('SkinTone', () {
    test('should have correct values', () {
      expect(SkinTone.defaultTone.value, 'Default');
      expect(SkinTone.light.value, 'Light');
      expect(SkinTone.mediumLight.value, 'MediumLight');
      expect(SkinTone.medium.value, 'Medium');
      expect(SkinTone.mediumDark.value, 'MediumDark');
      expect(SkinTone.dark.value, 'Dark');
    });
  });
}
