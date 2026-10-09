import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/bot.dart';
import '../theme/scholar_themes.dart';

/// Persisted settings + stats for Gomoku. Survives app restarts.
///
/// Stores: audio toggles + volume, renameable player names (2 slots),
/// theme / stone-style / marker-style choices (incl. custom theme colors),
/// game-mode setup (difficulty, color, swap opening, board options),
/// Pro unlock state, lifetime stats, and the mid-game save.
class GomokuSettings extends ChangeNotifier {
  static const _p = 'gomoku_';

  static const _kMusic = '${_p}music_on';
  static const _kSfx = '${_p}sfx_on';
  static const _kVolume = '${_p}volume';
  static const _kNames = '${_p}player_names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = '${_p}player_names_json';
  static const _kTheme = '${_p}theme_id';
  static const _kCustomPrefix = '${_p}custom_';
  static const _kStoneStyle = '${_p}stone_style';
  static const _kMarkerStyle = '${_p}marker_style';
  static const _kDifficulty = '${_p}difficulty'; // 0 beginner, 1 skilled, 2 master
  static const _kHumanColor = '${_p}human_color'; // 1 black, 2 white
  static const _kSwap = '${_p}swap_opening';
  static const _kCoords = '${_p}show_coordinates';
  static const _kLastMove = '${_p}last_move_marker';
  static const _kConfirmResign = '${_p}confirm_resign';
  static const _kUndo = '${_p}undo_allowed';
  static const _kWins = '${_p}wins';
  static const _kDraws = '${_p}draws';
  static const _kGames = '${_p}games_played';
  static const _kStreak = '${_p}best_streak';
  static const _kIsPro = '${_p}is_pro';

  static const defaultNames = ['You', 'Bot'];

  /// Encode the 2 player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'hearth';
  int stoneStyle = 0;
  int markerStyle = 0;
  BotDifficulty difficulty = BotDifficulty.skilled;
  int humanColor = 1;
  bool swapOpening = false;
  bool showCoordinates = false;
  bool lastMoveMarker = true;
  bool confirmResign = true;
  bool undoAllowed = true;
  int wins = 0;
  int draws = 0;
  int gamesPlayed = 0;
  int bestStreak = 0;
  int _streak = 0;
  bool isPro = false;

  /// Custom theme colors (ARGB ints). Defaults mirror Scholar's Hearth.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'paper': 0xFFF3EAD3,
    'paperCard': 0xFFFEF9EF,
    'inkText': 0xFF24211D,
    'inkSoft': 0xFF837469,
    'woodLight': 0xFFC89B5A,
    'woodMid': 0xFF8B5A2B,
    'woodDeep': 0xFF6F4315,
    'gridLine': 0xFF4A3A28,
    'accent': 0xFFC23B22,
    'accentDeep': 0xFFB02E16,
  };

  /// Builds the user-designed custom theme from stored colors.
  ScholarThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return ScholarThemeDef(
      id: 'custom',
      name: 'My Creation',
      paper: c('paper'),
      paperCard: c('paperCard'),
      inkText: c('inkText'),
      inkSoft: c('inkSoft'),
      woodLight: c('woodLight'),
      woodMid: c('woodMid'),
      woodDeep: c('woodDeep'),
      gridLine: c('gridLine'),
      accent: c('accent'),
      accentDeep: c('accentDeep'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'hearth';
    stoneStyle = (p.getInt(_kStoneStyle) ?? 0).clamp(0, StoneStyles.names.length - 1);
    markerStyle =
        (p.getInt(_kMarkerStyle) ?? 0).clamp(0, MarkerStyles.names.length - 1);
    difficulty =
        BotDifficulty.values[(p.getInt(_kDifficulty) ?? 1).clamp(0, 2)];
    humanColor = p.getInt(_kHumanColor) ?? 1;
    if (humanColor != 1 && humanColor != 2) humanColor = 1;
    swapOpening = p.getBool(_kSwap) ?? false;
    showCoordinates = p.getBool(_kCoords) ?? false;
    lastMoveMarker = p.getBool(_kLastMove) ?? true;
    confirmResign = p.getBool(_kConfirmResign) ?? true;
    undoAllowed = p.getBool(_kUndo) ?? true;
    wins = p.getInt(_kWins) ?? 0;
    draws = p.getInt(_kDraws) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestStreak = p.getInt(_kStreak) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kStoneStyle, stoneStyle);
    await p.setInt(_kMarkerStyle, markerStyle);
    await p.setInt(_kDifficulty, difficulty.index);
    await p.setInt(_kHumanColor, humanColor);
    await p.setBool(_kSwap, swapOpening);
    await p.setBool(_kCoords, showCoordinates);
    await p.setBool(_kLastMove, lastMoveMarker);
    await p.setBool(_kConfirmResign, confirmResign);
    await p.setBool(_kUndo, undoAllowed);
    await p.setInt(_kWins, wins);
    await p.setInt(_kDraws, draws);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kStreak, bestStreak);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (ScholarThemes.isProTheme(themeId)) {
      themeId = 'hearth';
      changed = true;
    }
    if (StoneStyles.isPro(stoneStyle)) {
      stoneStyle = 0;
      changed = true;
    }
    if (MarkerStyles.isPro(markerStyle)) {
      markerStyle = 0;
      changed = true;
    }
    if (difficulty == BotDifficulty.master) {
      difficulty = BotDifficulty.skilled;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && ScholarThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setStoneStyle(int v) async {
    v = v.clamp(0, StoneStyles.names.length - 1);
    if (!isPro && StoneStyles.isPro(v)) return;
    stoneStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMarkerStyle(int v) async {
    v = v.clamp(0, MarkerStyles.names.length - 1);
    if (!isPro && MarkerStyles.isPro(v)) return;
    markerStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(BotDifficulty d) async {
    // Master is a Pro feature.
    if (!isPro && d == BotDifficulty.master) return;
    difficulty = d;
    notifyListeners();
    await _save();
  }

  Future<void> setHumanColor(int c) async {
    if (c != 1 && c != 2) return;
    humanColor = c;
    notifyListeners();
    await _save();
  }

  Future<void> setSwapOpening(bool v) async {
    swapOpening = v;
    notifyListeners();
    await _save();
  }

  Future<void> setShowCoordinates(bool v) async {
    showCoordinates = v;
    notifyListeners();
    await _save();
  }

  Future<void> setLastMoveMarker(bool v) async {
    lastMoveMarker = v;
    notifyListeners();
    await _save();
  }

  Future<void> setConfirmResign(bool v) async {
    confirmResign = v;
    notifyListeners();
    await _save();
  }

  Future<void> setUndoAllowed(bool v) async {
    undoAllowed = v;
    notifyListeners();
    await _save();
  }

  /// Records a finished game. [winnerColor]: 1 black, 2 white, 0 draw.
  /// [humanWon]: true when seat 0 (the human / player one) won.
  Future<void> recordResult(
      {required int winnerColor, required bool humanWon}) async {
    gamesPlayed++;
    if (winnerColor == 0) {
      draws++;
      _streak = 0;
    } else if (humanWon) {
      wins++;
      _streak++;
      if (_streak > bestStreak) bestStreak = _streak;
    } else {
      _streak = 0;
    }
    notifyListeners();
    await _save();
  }

  void resetStats() {
    wins = 0;
    draws = 0;
    gamesPlayed = 0;
    bestStreak = 0;
    _streak = 0;
    notifyListeners();
    _save();
  }

  void resetDefaults() {
    musicOn = true;
    sfxOn = true;
    volume = 0.8;
    playerNames = List.of(defaultNames);
    themeId = 'hearth';
    stoneStyle = 0;
    markerStyle = 0;
    difficulty = BotDifficulty.skilled;
    humanColor = 1;
    swapOpening = false;
    showCoordinates = false;
    lastMoveMarker = true;
    confirmResign = true;
    undoAllowed = true;
    notifyListeners();
    _save();
  }

  // ---------------- mid-game save / resume ----------------

  Future<void> saveGame(Map<String, Object?> data) async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('${_p}saved_game', jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadSavedGame() async {
    final p = _prefs;
    if (p == null) return null;
    final raw = p.getString('${_p}saved_game');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSavedGame() async {
    final p = _prefs;
    if (p == null) return;
    await p.remove('${_p}saved_game');
  }
}
