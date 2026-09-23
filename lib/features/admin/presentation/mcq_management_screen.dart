import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../placement/domain/mcq_models.dart';
import 'mcq_editor_screen.dart';

class McqManagementScreen extends ConsumerWidget {
  const McqManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MCQ Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'PDFs'),
              Tab(text: 'Practice Tests'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PdfManagementTab(),
            _TestManagementTab(),
          ],
        ),
      ),
    );
  }
}

class _PdfManagementTab extends StatelessWidget {
  const _PdfManagementTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('mcq_pdfs').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final pdf = McqPdf.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
            return ListTile(
              title: Text(pdf.title),
              subtitle: Text(pdf.subjectId),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deletePdf(context, pdf.id),
              ),
            );
          },
        );
      },
    );
  }

  void _deletePdf(BuildContext context, String id) {
    FirebaseFirestore.instance.collection('mcq_pdfs').doc(id).delete();
  }
}

class _TestManagementTab extends StatelessWidget {
  const _TestManagementTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const McqEditorScreen())),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('mcq_tests').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final test = McqTest.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              return ListTile(
                title: Text(test.title),
                subtitle: Text('${test.subjectId} • ${test.questions.length} Qs'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => McqEditorScreen(test: test))),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTest(context, test.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _deleteTest(BuildContext context, String id) {
    FirebaseFirestore.instance.collection('mcq_tests').doc(id).delete();
  }
}
