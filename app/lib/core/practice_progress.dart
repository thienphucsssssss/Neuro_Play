import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class PracticeProgress {
  const PracticeProgress._(this._rounds);
  const PracticeProgress.empty() : _rounds = const {};

  final Map<String, String> _rounds;

  static const weeklyGoal = 5;
  static const xpPerRound = 30;
  static const xpPerLevel = 100;

  int get level => 1 + _rounds.length * xpPerRound ~/ xpPerLevel;
  int get levelXp => _rounds.length * xpPerRound % xpPerLevel;

  bool contains(String sessionId) => _rounds.containsKey(sessionId);

  PracticeProgress record(String sessionId, DateTime day) => contains(sessionId)
      ? this
      : PracticeProgress._({..._rounds, sessionId: _dayKey(day)});

  bool practicedOn(DateTime day) => _rounds.containsValue(_dayKey(day));

  int weeklyRounds(DateTime day) {
    final days = weekOf(day).map(_dayKey).toSet();
    return _rounds.values.where(days.contains).length;
  }

  int streak(DateTime today) {
    var day = practicedOn(today) ? today : _offsetDay(today, -1);
    var total = 0;
    while (practicedOn(day)) {
      total++;
      day = _offsetDay(day, -1);
    }
    return total;
  }

  double weeklyFraction(DateTime today) =>
      min(1.0, weeklyRounds(today) / weeklyGoal);

  static List<DateTime> weekOf(DateTime day) =>
      List.generate(7, (index) => _offsetDay(day, index + 1 - day.weekday));

  static DateTime _offsetDay(DateTime day, int offset) =>
      DateTime(day.year, day.month, day.day + offset);

  static String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

final class PracticeStore {
  const PracticeStore(this.userId);

  final String userId;
  static const _storage = FlutterSecureStorage();
  String get _key => 'neuro_play_practice_v1_$userId';

  Future<PracticeProgress> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return const PracticeProgress.empty();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded.values.any((value) => value is! String)) {
      throw const FormatException('Invalid practice history');
    }
    return PracticeProgress._(Map<String, String>.from(decoded));
  }

  Future<void> save(PracticeProgress progress) =>
      _storage.write(key: _key, value: jsonEncode(progress._rounds));
}
