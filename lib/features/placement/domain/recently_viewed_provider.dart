import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentItem {
  final String id;
  final String title;
  final String type; // 'question' | 'material'
  final String route;

  RecentItem({required this.id, required this.title, required this.type, required this.route});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type, 'route': route};
  factory RecentItem.fromJson(Map<String, dynamic> json) => RecentItem(
    id: json['id'],
    title: json['title'],
    type: json['type'],
    route: json['route'],
  );
}

class RecentlyViewedNotifier extends StateNotifier<List<RecentItem>> {
  RecentlyViewedNotifier() : super([]) {
    _loadFromPrefs();
  }

  static const _key = 'placement_recently_viewed';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key);
    if (data != null) {
      state = data.map((item) => RecentItem.fromJson(jsonDecode(item))).toList();
    }
  }

  Future<void> addItem(RecentItem item) async {
    // Remove if already exists to move to top
    final newState = state.where((i) => i.id != item.id).toList();
    newState.insert(0, item);
    
    // Keep only last 5 items
    if (newState.length > 5) newState.removeLast();
    
    state = newState;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.map((i) => jsonEncode(i.toJson())).toList());
  }
}

final recentlyViewedProvider = StateNotifierProvider<RecentlyViewedNotifier, List<RecentItem>>((ref) {
  return RecentlyViewedNotifier();
});
