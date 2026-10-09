import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/services/settings_service.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// two names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string
/// (gomoku_player_names_json).
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Bot Bob'];
    final decoded = GomokuSettings.decodePlayerNames(
      GomokuSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    expect(decoded[0], 'Wajiha');
    expect(decoded[1], 'Bot Bob');
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      GomokuSettings.decodePlayerNames(null),
      GomokuSettings.defaultNames,
    );
    expect(
      GomokuSettings.decodePlayerNames('definitely not json'),
      GomokuSettings.defaultNames,
    );
    expect(
      GomokuSettings.decodePlayerNames('["only"]'),
      GomokuSettings.defaultNames,
    );
    expect(
      GomokuSettings.decodePlayerNames('{"a":1}'),
      GomokuSettings.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded =
        GomokuSettings.decodePlayerNames('["Wajiha","  "]');
    expect(decoded, ['Wajiha', 'Bot']);
  });
}
