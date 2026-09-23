import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/interview_models.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/responsive_layout.dart';

final interviewPdfsProvider = FutureProvider.family<List<InterviewPdf>, String>((ref, subjectId) async {
  final box = await Hive.openBox('interview_pdfs_cache');
  final cachedData = box.get(subjectId);
  List<InterviewPdf> pdfs = [];

  if (cachedData != null) {
    pdfs = (cachedData as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      return InterviewPdf.fromMap(map, map['id'] ?? '');
    }).toList();
  }

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('interview_pdfs')
        .where('subjectId', isEqualTo: subjectId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    final remotePdfs = snapshot.docs.map((doc) => InterviewPdf.fromMap(doc.data(), doc.id)).toList();
    
    await box.put(subjectId, remotePdfs.map((e) {
      final map = e.toMap();
      map['id'] = e.id;
      return map;
    }).toList());
    
    return remotePdfs;
  } catch (e) {
    return pdfs;
  }
});

class InterviewModuleScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;

  const InterviewModuleScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfsAsync = ref.watch(interviewPdfsProvider(subjectId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$subjectName Interview Qs'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(interviewPdfsProvider(subjectId).future),
        child: ResponsiveLayout(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '📄 Interview PDFs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              pdfsAsync.when(
                data: (pdfs) => pdfs.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No PDFs available yet.'),
                      ))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pdfs.length,
                        itemBuilder: (context, index) => _PdfTile(pdf: pdfs[index]),
                      ),
                loading: () => ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 5,
                  itemBuilder: (context, index) => const McqTileSkeleton(),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfTile extends StatelessWidget {
  final InterviewPdf pdf;
  const _PdfTile({required this.pdf});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(pdf.title),
        subtitle: Text(
          '${(pdf.size / 1024).toStringAsFixed(1)} KB • ${pdf.createdAt != null ? DateFormat('dd MMM yyyy').format(pdf.createdAt!) : 'N/A'}',
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
