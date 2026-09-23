import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/mcq_repository.dart';
import '../domain/mcq_models.dart';
import '../data/mcq_results_repository.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/responsive_layout.dart';

final pdfsProvider = FutureProvider.family<List<McqPdf>, String>((ref, subjectId) {
  return ref.watch(mcqRepositoryProvider).getPdfs(subjectId);
});

final testsProvider = FutureProvider.family<List<McqTest>, String>((ref, subjectId) {
  return ref.watch(mcqRepositoryProvider).getTests(subjectId);
});

class McqModuleScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;

  const McqModuleScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfsAsync = ref.watch(pdfsProvider(subjectId));
    final testsAsync = ref.watch(testsProvider(subjectId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$subjectName MCQs'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pdfsProvider(subjectId));
          ref.invalidate(testsProvider(subjectId));
        },
        child: ResponsiveLayout(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('📄 MCQ PDFs'),
              pdfsAsync.when(
                data: (pdfs) => pdfs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No PDFs available yet.'),
                      )
                    : Column(
                        children: pdfs.map((pdf) => _PdfTile(pdf: pdf)).toList(),
                      ),
                loading: () => Column(
                  children: List.generate(3, (index) => const McqTileSkeleton()),
                ),
                error: (e, _) => Text('Error loading PDFs: $e'),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('🧪 Practice Tests'),
              testsAsync.when(
                data: (tests) => tests.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No practice tests available yet.'),
                      )
                    : Column(
                        children: tests.map((test) => _TestTile(test: test)).toList(),
                      ),
                loading: () => Column(
                  children: List.generate(3, (index) => const McqTileSkeleton()),
                ),
                error: (e, _) => Text('Error loading tests: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PdfTile extends StatelessWidget {
  final McqPdf pdf;
  const _PdfTile({required this.pdf});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(pdf.title),
        subtitle: Text(
          '${(pdf.size / 1024).toStringAsFixed(1)} KB • Updated: ${pdf.createdAt != null ? DateFormat('dd MMM yyyy').format(pdf.createdAt!) : 'N/A'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () {
          context.push('/placement/pdf-viewer', extra: {
            'title': pdf.title,
            'pdfUrl': pdf.pdfUrl,
          });
        },
      ),
    );
  }
}

class _TestTile extends ConsumerWidget {
  final McqTest test;
  const _TestTile({required this.test});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.read(mcqResultsRepositoryProvider).getResult(test.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getDifficultyColor(test.difficulty).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.quiz, color: _getDifficultyColor(test.difficulty)),
        ),
        title: Text(test.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${test.questions.length} Questions • ${test.difficulty.toUpperCase()}'),
            if (result != null)
              Text(
                'Last Score: ${result['score']}/${result['total']} (${result['percentage']}%)',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
              ),
          ],
        ),
        trailing: const Icon(Icons.play_arrow_rounded, color: Colors.green),
        onTap: () {
          context.push('/placement/mcq-test/${test.id}', extra: test);
        },
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
