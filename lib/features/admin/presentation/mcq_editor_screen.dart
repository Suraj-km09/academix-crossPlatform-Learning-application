import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../placement/domain/mcq_models.dart';

class McqEditorScreen extends StatefulWidget {
  final McqTest? test;
  const McqEditorScreen({super.key, this.test});

  @override
  State<McqEditorScreen> createState() => _McqEditorScreenState();
}

class _McqEditorScreenState extends State<McqEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  String _difficulty = 'easy';
  List<McqQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.test?.title ?? '');
    _subjectController = TextEditingController(
      text: widget.test?.subjectId ?? '',
    );
    _difficulty = widget.test?.difficulty ?? 'easy';
    _questions = widget.test?.questions != null
        ? List.from(widget.test!.questions)
        : [];
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        McqQuestion(question: '', options: ['', '', '', ''], answerIndex: 0),
      );
    });
  }

  Future<void> _saveTest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }

    final testData = {
      'title': _titleController.text,
      'subjectId': _subjectController.text.toLowerCase(),
      'difficulty': _difficulty,
      'isActive': true,
      'questions': _questions.map((q) => q.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.test == null) {
        await FirebaseFirestore.instance.collection('mcq_tests').add(testData);
      } else {
        await FirebaseFirestore.instance
            .collection('mcq_tests')
            .doc(widget.test!.id)
            .update(testData);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.test == null ? 'Create Test' : 'Edit Test'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveTest),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Test Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject ID (e.g. dbms)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _difficulty,
                    items: ['easy', 'medium', 'hard']
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Question'),
                      ),
                    ],
                  ),
                  ..._questions.asMap().entries.map((entry) {
                    int idx = entry.key;
                    McqQuestion q = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Question ${idx + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      setState(() => _questions.removeAt(idx)),
                                ),
                              ],
                            ),
                            TextFormField(
                              initialValue: q.question,
                              decoration: const InputDecoration(
                                labelText: 'Question text',
                              ),
                              maxLines: 2,
                              onChanged: (v) => _questions[idx] = McqQuestion(
                                question: v,
                                options: q.options,
                                answerIndex: q.answerIndex,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              4,
                              (optIdx) => TextFormField(
                                initialValue: q.options[optIdx],
                                decoration: InputDecoration(
                                  labelText:
                                      'Option ${String.fromCharCode(65 + optIdx)}',
                                  prefixIcon: Radio<int>(
                                    value: optIdx,
                                    groupValue: q.answerIndex,
                                    onChanged: (v) => setState(
                                      () => _questions[idx] = McqQuestion(
                                        question: q.question,
                                        options: q.options,
                                        answerIndex: v!,
                                      ),
                                    ),
                                  ),
                                ),
                                onChanged: (v) {
                                  List<String> newOpts = List.from(q.options);
                                  newOpts[optIdx] = v;
                                  _questions[idx] = McqQuestion(
                                    question: q.question,
                                    options: newOpts,
                                    answerIndex: q.answerIndex,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 80), // Space for FAB-like area
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
