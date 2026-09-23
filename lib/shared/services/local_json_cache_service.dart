import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalJsonCacheEntry {
  const LocalJsonCacheEntry({required this.payload, required this.cachedAt});

  final dynamic payload;
  final DateTime cachedAt;

  bool isFresh(Duration maxAge) {
    return DateTime.now().difference(cachedAt) <= maxAge;
  }
}

class LocalJsonCacheService {
  LocalJsonCacheService._();

  static const String _keyPrefix = 'local_json_cache::';
  static final LocalJsonCacheService instance = LocalJsonCacheService._();

  String _storageKey(String key) => '$_keyPrefix$key';

  Future<void> write(String key, dynamic payload) async {
    final prefs = await SharedPreferences.getInstance();
    final wrapper = <String, dynamic>{
      'cachedAtMs': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    };
    await prefs.setString(_storageKey(key), jsonEncode(wrapper));
  }

  Future<LocalJsonCacheEntry?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(key));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final map = decoded.map((k, v) => MapEntry(k.toString(), v));

      final cachedAtMs = map['cachedAtMs'];
      if (cachedAtMs is! int) {
        return null;
      }

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      return LocalJsonCacheEntry(payload: map['payload'], cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(key));
  }

  Future<void> clearPrefix(String keyPrefix) async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedPrefix = _storageKey(keyPrefix);

    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(resolvedPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  Future<void> clearAllManaged() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_keyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
