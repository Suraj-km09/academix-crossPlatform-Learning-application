import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'mcq_management_screen.dart';

class PlacementManagementScreen extends StatelessWidget {
  const PlacementManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Management'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildAdminCard(
                context,
                title: 'MCQ PDFs',
                subtitle: 'Verbal/CS PDFs',
                icon: Icons.picture_as_pdf_rounded,
                color: Colors.orange,
                onTap: () => context.push('/admin/placement/mcq-uploader'),
              ),
              _buildAdminCard(
                context,
                title: 'MCQ Tests',
                subtitle: 'Quizzes',
                icon: Icons.quiz_rounded,
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const McqManagementScreen()),
                ),
              ),
              _buildAdminCard(
                context,
                title: 'Interview',
                subtitle: 'Subject-wise Interview Qs',
                icon: Icons.question_answer_rounded,
                color: Colors.deepPurple,
                onTap: () => context.push('/admin/placement/interview-uploader'),
              ),
              _buildAdminCard(
                context,
                title: 'DSA',
                subtitle: 'Bulk Upload Coding Qs',
                icon: Icons.code_rounded,
                color: Colors.blue,
                onTap: () => context.push('/admin/placement/dsa-uploader'),
              ),
              _buildAdminCard(
                context,
                title: 'Course',
                subtitle: 'Generic Notes/\nSyllabus',
                icon: Icons.auto_stories_rounded,
                color: Colors.green,
                onTap: () => context.push('/admin/placement/materials'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final width = (MediaQuery.of(context).size.width - 48) / 2;
    return SizedBox(
      width: width,
      height: 160,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.1)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
