import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/bot.dart';

/// Persisted user settings, match stats and mid-game save.
/// Backed by shared_preferences. All keys are `gomoku_`-prefixed.
class GomokuSettings extends ChangeNotifier {
  static const _p = 'gomoku_';

  // audio
  bool musicOn = true;
  bool sfxOn = true;
  double musicVolume = 0.6;
  double sfxVolume = 0.8;

  // game prefs
  BotDifficulty difficulty = BotDifficulty.skilled;
  int humanColor = 1; // 1 = black (first), 2 = white
  bool swapOpening = false;
  bool showCoordinates = false;
  bool lastMoveMarker = true;
  bool confirmResign = true;
  bool undoAllowed = true;

  // match stats: wins = black-side wins, losses = white-side wins
  int wins = 0;
  int losses = 0;
  int draws = 0;
  int streak = 0;
  int streakSide = 0; // 1 black, 2 white, 0 none

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    musicOn = sp.getBool('${_p}musicOn') ?? true;
    sfxOn = sp.getBool('${_p}sfxOn') ?? true;
    musicVolume = sp.getDouble('${_p}musicVolume') ?? 0.6;
    sfxVolume = sp.getDouble('${_p}sfxVolume') ?? 0.8;
    difficulty = BotDifficulty.values[sp.getInt('${_p}difficulty') ?? 1];
    humanColor = sp.getInt('${_p}humanColor') ?? 1;
    swapOpening = sp.getBool('${_p}swapOpening') ?? false;
    showCoordinates = sp.getBool('${_p}showCoordinates') ?? false;
    lastMoveMarker = sp.getBool('${_p}lastMoveMarker') ?? true;
    confirmResign = sp.getBool('${_p}confirmResign') ?? true;
    undoAllowed = sp.getBool('${_p}undoAllowed') ?? true;
    wins = sp.getInt('${_p}wins') ?? 0;
    losses = sp.getInt('${_p}losses') ?? 0;
    draws = sp.getInt('${_p}draws') ?? 0;
    streak = sp.getInt('${_p}streak') ?? 0;
    streakSide = sp.getInt('${_p}streakSide') ?? 0;
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('${_p}musicOn', musicOn);
    await sp.setBool('${_p}sfxOn', sfxOn);
    await sp.setDouble('${_p}musicVolume', musicVolume);
    await sp.setDouble('${_p}sfxVolume', sfxVolume);
    await sp.setInt('${_p}difficulty', difficulty.index);
    await sp.setInt('${_p}humanColor', humanColor);
    await sp.setBool('${_p}swapOpening', swapOpening);
    await sp.setBool('${_p}showCoordinates', showCoordinates);
    await sp.setBool('${_p}lastMoveMarker', lastMoveMarker);
    await sp.setBool('${_p}confirmResign', confirmResign);
    await sp.setBool('${_p}undoAllowed', undoAllowed);
    await sp.setInt('${_p}wins', wins);
    await sp.setInt('${_p}losses', losses);
    await sp.setInt('${_p}draws', draws);
    await sp.setInt('${_p}streak', streak);
    await sp.setInt('${_p}streakSide', streakSide);
  }

  void update(void Function() f) {
    f();
    _save();
    notifyListeners();
  }

  /// Records a finished game. winnerColor: 1 black, 2 white, 0 draw.
  void recordResult(int winnerColor) {
    update(() {
      if (winnerColor == 0) {
        draws++;
        streak = 0;
        streakSide = 0;
      } else {
        if (winnerColor == 1) {
          wins++;
        } else {
          losses++;
        }
        streak = streakSide == winnerColor ? streak + 1 : 1;
        streakSide = winnerColor;
      }
    });
  }

  void resetStats() => update(() {
        wins = 0;
        losses = 0;
        draws = 0;
        streak = 0;
        streakSide = 0;
      });

  void resetDefaults() => update(() {
        musicOn = true;
        sfxOn = true;
        musicVolume = 0.6;
        sfxVolume = 0.8;
        difficulty = BotDifficulty.skilled;
        humanColor = 1;
        swapOpening = false;
        showCoordinates = false;
        lastMoveMarker = true;
        confirmResign = true;
        undoAllowed = true;
      });

  // ---------------- mid-game save / resume ----------------

  Future<void> saveGame(Map<String, Object?> data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('${_p}savedGame', jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadSavedGame() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('${_p}savedGame');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSavedGame() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('${_p}savedGame');
  }
}
