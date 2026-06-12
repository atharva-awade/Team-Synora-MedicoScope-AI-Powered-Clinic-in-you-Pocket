import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:medicoscope/core/constants/api_constants.dart';

class CoinsProvider extends ChangeNotifier {
  int _totalCoins = 0;
  int get totalCoins => _totalCoins;

  int _lastEarned = 0;
  int get lastEarned => _lastEarned;

  int _totalSessions = 0;
  int get totalSessions => _totalSessions;

  int _currentStreak = 0;
  int get currentStreak => _currentStreak;

  int _longestStreak = 0;
  int get longestStreak => _longestStreak;

  String? _lastSessionDate;
  String? _lastChatRewardDate;
  bool _streak3Claimed = false;
  bool _streak7Claimed = false;
  String? _authToken;

  /// Whether Mind Space check-in was done today
  bool get checkedInToday {
    if (_lastSessionDate == null) return false;
    return _lastSessionDate == _today;
  }

  /// Whether chat reward was earned today
  bool get chatRewardedToday {
    if (_lastChatRewardDate == null) return false;
    return _lastChatRewardDate == _today;
  }

  /// Whether 3-day streak bonus was claimed this streak
  bool get streak3Claimed => _streak3Claimed;

  /// Whether 7-day streak bonus was claimed this streak
  bool get streak7Claimed => _streak7Claimed;

  /// Whether 3-day streak bonus is available to claim now
  bool get streak3Available => _currentStreak >= 3 && !_streak3Claimed;

  /// Whether 7-day streak bonus is available to claim now
  bool get streak7Available => _currentStreak >= 7 && !_streak7Claimed;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  CoinsProvider() {
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final prefs = await SharedPreferences.getInstance();
    _totalCoins = prefs.getInt('mind_coins') ?? 0;
    _totalSessions = prefs.getInt('mind_sessions') ?? 0;
    _currentStreak = prefs.getInt('mind_streak') ?? 0;
    _longestStreak = prefs.getInt('mind_longest_streak') ?? 0;
    _lastSessionDate = prefs.getString('mind_last_session');
    _lastChatRewardDate = prefs.getString('mind_last_chat_reward');
    _streak3Claimed = prefs.getBool('mind_streak3_claimed') ?? false;
    _streak7Claimed = prefs.getBool('mind_streak7_claimed') ?? false;
    notifyListeners();
  }

  /// Called after a Mind Space voice check-in. Awards base coins + streak bonuses.
  /// Returns total coins earned (including any streak bonuses).
  Future<int> addCoins(int amount) async {
    int totalEarned = amount;
    _lastEarned = amount;
    _totalCoins += amount;
    _totalSessions++;

    // Streak logic
    final today = _today;
    if (_lastSessionDate != null && _lastSessionDate != today) {
      final lastDate = DateTime.parse(_lastSessionDate!);
      final diff = DateTime.now().difference(lastDate).inDays;
      if (diff == 1) {
        _currentStreak++;
      } else if (diff > 1) {
        _currentStreak = 1;
        // Reset streak bonus claims on broken streak
        _streak3Claimed = false;
        _streak7Claimed = false;
      }
    } else if (_lastSessionDate == null) {
      _currentStreak = 1;
    }
    // same day = streak stays unchanged
    _lastSessionDate = today;

    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }

    // Auto-award streak bonuses
    if (_currentStreak >= 3 && !_streak3Claimed) {
      _streak3Claimed = true;
      _totalCoins += 15;
      totalEarned += 15;
    }
    if (_currentStreak >= 7 && !_streak7Claimed) {
      _streak7Claimed = true;
      _totalCoins += 50;
      totalEarned += 50;
    }

    _lastEarned = totalEarned;
    notifyListeners();
    await _persist();
    _syncToServer();
    return totalEarned;
  }

  /// Called after any disease-detection action (PDF, vitals, image, PPG, symptom check,
  /// skin scan, heart sound, og vitals session). Awards a fixed amount per
  /// (modality × day) tuple so users can't farm coins by re-running the same
  /// scan 20 times in a row, but they can still earn across different
  /// modalities in the same day.
  /// Returns coins actually awarded (0 if the daily cap for this modality
  /// has already been hit today).
  Future<int> addDetectionCoins({
    required String modality,
    int amount = 10,
  }) async {
    final today = _today;
    final prefs = await SharedPreferences.getInstance();
    final key = 'detect_${modality}_last';
    final last = prefs.getString(key);
    if (last == today) return 0;
    await prefs.setString(key, today);
    _totalCoins += amount;
    _lastEarned = amount;
    notifyListeners();
    await prefs.setInt('mind_coins', _totalCoins);
    _syncToServer();
    return amount;
  }

  /// Called after a successful chatbot interaction. Awards 5 coins, max once per day.
  /// Returns coins earned (5 or 0).
  Future<int> addChatCoins() async {
    final today = _today;
    if (_lastChatRewardDate == today) return 0;

    _lastChatRewardDate = today;
    _totalCoins += 5;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mind_coins', _totalCoins);
    await prefs.setString('mind_last_chat_reward', today);
    _syncToServer();
    return 5;
  }

  Future<bool> spendCoins(int amount) async {
    if (_totalCoins < amount) return false;
    _totalCoins -= amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mind_coins', _totalCoins);
    _syncToServer();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mind_coins', _totalCoins);
    await prefs.setInt('mind_sessions', _totalSessions);
    await prefs.setInt('mind_streak', _currentStreak);
    await prefs.setInt('mind_longest_streak', _longestStreak);
    await prefs.setString('mind_last_session', _lastSessionDate!);
    await prefs.setBool('mind_streak3_claimed', _streak3Claimed);
    await prefs.setBool('mind_streak7_claimed', _streak7Claimed);
  }

  /// Set auth token for DB sync
  void setToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    if (token != null) {
      _loadFromServer();
    }
  }

  /// Load rewards from server DB
  Future<void> _loadFromServer() async {
    if (_authToken == null) return;
    try {
      final api = ApiService(token: _authToken);
      final response = await api.get(ApiConstants.rewards);
      final rewards = response['rewards'] as Map<String, dynamic>;

      final serverCoins = rewards['totalCoins'] as int? ?? 0;
      // Use whichever is higher (local or server) to avoid data loss
      if (serverCoins > _totalCoins) {
        _totalCoins = serverCoins;
        _totalSessions = rewards['totalSessions'] as int? ?? _totalSessions;
        _currentStreak = rewards['currentStreak'] as int? ?? _currentStreak;
        _longestStreak = rewards['longestStreak'] as int? ?? _longestStreak;
        _lastSessionDate =
            rewards['lastSessionDate'] as String? ?? _lastSessionDate;
        _lastChatRewardDate =
            rewards['lastChatRewardDate'] as String? ?? _lastChatRewardDate;
        _streak3Claimed = rewards['streak3Claimed'] as bool? ?? _streak3Claimed;
        _streak7Claimed = rewards['streak7Claimed'] as bool? ?? _streak7Claimed;
        notifyListeners();
        await _persist();
      } else if (_totalCoins > serverCoins) {
        // Local is ahead, push to server
        _syncToServer();
      }
    } catch (_) {
      // Server unavailable, continue with local data
    }
  }

  /// Sync current rewards to server DB
  Future<void> _syncToServer() async {
    if (_authToken == null) return;
    try {
      final api = ApiService(token: _authToken);
      await api.put(ApiConstants.rewards, {
        'totalCoins': _totalCoins,
        'totalSessions': _totalSessions,
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
        'lastSessionDate': _lastSessionDate,
        'lastChatRewardDate': _lastChatRewardDate,
        'streak3Claimed': _streak3Claimed,
        'streak7Claimed': _streak7Claimed,
      });
    } catch (_) {
      // Silently fail — local data is primary
    }
  }
}
