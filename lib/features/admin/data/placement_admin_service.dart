import 'package:cloud_firestore/cloud_firestore.dart';

class PlacementAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> clearDsaData() async {
    // Delete all questions
    final questions = await _firestore.collection('dsa_questions').get();
    final qBatch = _firestore.batch();
    for (var doc in questions.docs) {
      qBatch.delete(doc.reference);
    }
    if (questions.docs.isNotEmpty) await qBatch.commit();
    
    // Delete all topics
    final topics = await _firestore.collection('dsa_topics').get();
    final tBatch = _firestore.batch();
    for (var doc in topics.docs) {
      tBatch.delete(doc.reference);
    }
    if (topics.docs.isNotEmpty) await tBatch.commit();
  }

  Future<void> uploadDsaQuestions(String rawText) async {
    final lines = rawText.split('\n');
    String currentTopic = '';
    String currentDifficulty = 'Easy';
    int topicOrder = 1; // Start from 1 to ensure order matches the file exactly

    final topicMap = {
      'ARRAYS': 'arrays',
      'DYNAMIC PROGRAMING': 'dp',
      'DYNAMIC PROGRAMMING': 'dp',
      'STRINGS': 'strings',
      'MATHS': 'maths',
      'GREEDY': 'greedy',
      'DFS': 'dfs',
      'TREE': 'trees',
      'TREES': 'trees',
      'BINARY SEARCH': 'binary_search',
      'BFS': 'bfs',
      'TWO POINTER': 'two_pointer',
      'BACKTRACKING': 'backtracking',
      'STACK': 'stack_queue',
      'DESIGN': 'design',
      'GRAPH': 'graphs',
      'LINKED LIST': 'linked_list',
      'HEAP': 'heap',
      'SLIDING WINDOW': 'sliding_window',
      'BASICS OF PROGRAMMING': 'basics',
      'SORTING': 'sorting',
      'BIT MANIPULATION': 'bit_manipulation',
      'TRIES': 'tries',
    };

    WriteBatch batch = _firestore.batch();
    int opsCount = 0;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      final upperLine = line.toUpperCase();

      // 1. Identify Topic
      // If it's a known topic OR looks like a new topic header
      if (topicMap.containsKey(upperLine) || (upperLine.length > 3 && !upperLine.contains('HTTP') && !upperLine.startsWith('-') && !['EASY', 'MEDIUM', 'HARD', 'TOPICS & QUESTIONS'].any((k) => upperLine.contains(k)))) {
        currentTopic = topicMap[upperLine] ?? upperLine.toLowerCase().replaceAll(' ', '_');
        
        final topicRef = _firestore.collection('dsa_topics').doc(currentTopic);
        batch.set(topicRef, {
          'name': _capitalize(line),
          'order': topicOrder++,
        }, SetOptions(merge: true));
        opsCount++;
        continue;
      }

      // 2. Identify Difficulty
      if (upperLine.contains('EASY')) {
        currentDifficulty = 'Easy';
        continue;
      } else if (upperLine.contains('MEDIUM')) {
        currentDifficulty = 'Medium';
        continue;
      } else if (upperLine.contains('HARD')) {
        currentDifficulty = 'Hard';
        continue;
      }

      // 3. Process URLs and Labels
      if (line.contains('http')) {
        if (currentTopic.isEmpty) continue;

        String title = '';
        String url = '';

        if (line.contains('-')) {
          // Labeled format: "- Title URL"
          // Using regex to find the first occurrence of http to split title and url
          final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(line);
          if (urlMatch != null) {
            url = urlMatch.group(0)!;
            final beforeUrl = line.substring(0, urlMatch.start).trim();
            title = beforeUrl.startsWith('-') ? beforeUrl.substring(1).trim() : beforeUrl;
          }
        } else {
          // Link-only format: Split by whitespace and take first token starting with http
          final tokens = line.split(RegExp(r'\s+'));
          for(var token in tokens) {
            if(token.toLowerCase().startsWith('http')) {
              url = token;
              break;
            }
          }
          title = _generateTitleFromUrl(url);
        }

        if (url.isEmpty) continue;

        final questionId = _generateIdFromUrl(url);
        final platform = _detectPlatform(url);
        
        final questionRef = _firestore.collection('dsa_questions').doc(questionId);
        batch.set(questionRef, {
          'topicId': currentTopic,
          'difficulty': currentDifficulty,
          'title': title.isEmpty ? 'Untitled Question' : title,
          'link': url,
          'platform': platform,
        }, SetOptions(merge: true));
        opsCount++;

        // Firestore batch limit is 500 operations
        if (opsCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          opsCount = 0;
        }
      }
    }

    if (opsCount > 0) await batch.commit();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('leetcode')) return 'LeetCode';
    if (lower.contains('geeksforgeeks')) return 'GeeksforGeeks';
    if (lower.contains('youtube') || lower.contains('youtu.be')) return 'YouTube';
    if (lower.contains('naukri') || lower.contains('code360')) return 'Code360';
    return 'External';
  }

  String _generateIdFromUrl(String url) {
    try {
      var clean = url.split('?')[0];
      while (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
      final parts = clean.split('/');
      if (parts.isNotEmpty) {
        final slug = parts.last;
        if (slug.isNotEmpty && slug != '/') return slug;
      }
    } catch (_) {}
    return 'q_${url.hashCode.abs()}';
  }

  String _generateTitleFromUrl(String url) {
    final id = _generateIdFromUrl(url);
    if (id.startsWith('q_')) return 'Question ${id.substring(2)}';
    return id.split('-').where((word) => word.isNotEmpty).map((word) => _capitalize(word)).join(' ');
  }
}
