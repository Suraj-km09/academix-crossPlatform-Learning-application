import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/mcq_models.dart';
import '../data/mcq_results_repository.dart';

class McqTestScreen extends ConsumerStatefulWidget {
  final McqTest test;

  const McqTestScreen({super.key, required this.test});

  @override
  ConsumerState<McqTestScreen> createState() => _McqTestScreenState();
}

class _McqTestScreenState extends ConsumerState<McqTestScreen> {
  int _currentIndex = 0;
  final Map<int, int?> _userAnswers = {};
  bool _isSubmitted = false;

  void _nextQuestion() {
    if (_currentIndex < widget.test.questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _submitTest() async {
    final score = _calculateScore();
    await ref.read(mcqResultsRepositoryProvider).saveResult(
      testId: widget.test.id,
      score: score,
      total: widget.test.questions.length,
    );
    setState(() => _isSubmitted = true);
    _showResultDialog();
  }

  int _calculateScore() {
    int score = 0;
    _userAnswers.forEach((index, answer) {
      if (answer == widget.test.questions[index].answerIndex) {
        score++;
      }
    });
    return score;
  }

  void _showResultDialog() {
    final score = _calculateScore();
    final total = widget.test.questions.length;
    final accuracy = (score / total * 100).toStringAsFixed(1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Test Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score / $total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Accuracy: $accuracy%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() => _isSubmitted = true);
            },
            child: const Text('Review Answers'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit test
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.test.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.test.title),
        actions: [
          if (!_isSubmitted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${widget.test.questions.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.test.questions.length,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_currentIndex + 1}',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(question.options.length, (index) {
                    final isSelected = _userAnswers[_currentIndex] == index;
                    final isCorrect = question.answerIndex == index;
                    
                    Color? tileColor;
                    if (_isSubmitted) {
                      if (isCorrect) tileColor = Colors.green.withOpacity(0.2);
                      else if (isSelected) tileColor = Colors.red.withOpacity(0.2);
                    } else if (isSelected) {
                      tileColor = Colors.blue.withOpacity(0.1);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isSubmitted && isCorrect 
                              ? Colors.green 
                              : (isSelected ? Colors.blue : Colors.grey.shade300),
                          width: isSelected || (_isSubmitted && isCorrect) ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: _isSubmitted ? null : () {
                          setState(() {
                            _userAnswers[_currentIndex] = index;
                          });
                        },
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(question.options[index]),
                        trailing: _isSubmitted 
                            ? (isCorrect 
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : (isSelected ? const Icon(Icons.cancel, color: Colors.red) : null))
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          _buildNavigation(),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: _currentIndex > 0 ? _prevQuestion : null,
            child: const Text('Previous'),
          ),
          if (_currentIndex == widget.test.questions.length - 1 && !_isSubmitted)
            ElevatedButton(
              onPressed: _submitTest,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('Submit Test'),
            )
          else
            ElevatedButton(
              onPressed: _currentIndex < widget.test.questions.length - 1 ? _nextQuestion : null,
              child: const Text('Next'),
            ),
        ],
      ),
    );
  }
}
