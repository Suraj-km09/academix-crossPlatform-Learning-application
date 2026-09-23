import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final mcqResultsRepositoryProvider = Provider((ref) => McqResultsRepository());

class McqResultsRepository {
  static const String _resultsBoxName = 'mcq_test_results';

  Future<void> saveResult({
    required String testId,
    required int score,
    required int total,
  }) async {
    final box = await Hive.openBox(_resultsBoxName);
    final percentage = (score / total * 100).toStringAsFixed(1);
    await box.put(testId, {
      'score': score,
      'total': total,
      'percentage': percentage,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? getResult(String testId) {
    final box = Hive.box(_resultsBoxName);
    final data = box.get(testId);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> init() async {
    await Hive.openBox(_resultsBoxName);
  }
}
