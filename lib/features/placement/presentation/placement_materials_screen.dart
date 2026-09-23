import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/placement_providers.dart';
import '../domain/placement_models.dart';
import '../domain/recently_viewed_provider.dart';
import '../../../shared/widgets/responsive_layout.dart';

class PlacementMaterialsScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;

  const PlacementMaterialsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(courseMaterialsProvider(subjectId));
    final user = ref.watch(currentUserStreamProvider).valueOrNull;
    final isAdmin = user?.role == 'admin';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          subjectName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: materialsAsync.when(
        data: (materials) {
          final syllabus = materials.where((m) => m.title.toLowerCase() == 'syllabus').firstOrNull;
          final notes = materials.where((m) => m.title.toLowerCase() != 'syllabus' && m.type == 'pdf').toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(courseMaterialsProvider(subjectId).future),
            child: ResponsiveLayout(
              padding: EdgeInsets.zero,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  _buildSectionTitle(context, 'SUBJECT SYLLABUS'),
                  const SizedBox(height: 12),
                  if (syllabus != null)
                    _buildSyllabusCard(context, ref, syllabus, isAdmin)
                  else
                    _buildEmptyState(
                      context,
                      'Official syllabus hasn\'t been uploaded yet.',
                      isAdmin: false, 
                    ),
                  
                  const SizedBox(height: 32),
                  
                  _buildSectionTitle(context, 'TOPIC WISE NOTES'),
                  const SizedBox(height: 12),
                  if (notes.isEmpty)
                    _buildEmptyState(
                      context,
                      'Detailed notes for topics will appear here.',
                      icon: Icons.note_alt_outlined,
                      isAdmin: isAdmin,
                      subjectId: subjectId,
                    )
                  else
                    ...notes.map((note) => _buildTopicSlide(context, ref, note, isAdmin)),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => ResponsiveLayout(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildSectionTitle(context, 'SUBJECT SYLLABUS'),
              const SizedBox(height: 12),
              const PlacementMaterialSkeleton(),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'TOPIC WISE NOTES'),
              const SizedBox(height: 12),
              ...List.generate(5, (index) => const PlacementMaterialSkeleton()),
            ],
          ),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final color = Theme.of(context).textTheme.labelSmall?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSyllabusCard(BuildContext context, WidgetRef ref, CourseMaterial syllabus, bool isAdmin) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.12), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPdf(context, ref, syllabus),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Curriculum',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Official Syllabus PDF',
                        style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  _buildDeleteButton(context, ref, syllabus.id)
                else
                  Icon(Icons.arrow_forward_rounded, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSlide(BuildContext context, WidgetRef ref, CourseMaterial note, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openPdf(context, ref, note),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isAdmin)
                    _buildDeleteButton(context, ref, note.id)
                  else
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, WidgetRef ref, String id) {
    return IconButton(
      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 24),
      onPressed: () => _confirmDelete(context, ref, id),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, {IconData icon = Icons.info_outline_rounded, bool isAdmin = false, String? subjectId}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? cs.onSurfaceVariant, fontSize: 14),
          ),
          if (isAdmin && subjectId != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/admin/placement/materials', extra: subjectId),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Upload Material'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.surface,
                foregroundColor: cs.primary,
                elevation: 0,
                side: BorderSide(color: cs.primary.withOpacity(0.12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPdf(BuildContext context, WidgetRef ref, CourseMaterial material) {
    ref.read(recentlyViewedProvider.notifier).addItem(RecentItem(
      id: material.id,
      title: material.title,
      type: 'material',
      route: material.fileUrl,
    ));
    
    if (material.fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Document link is missing.')),
      );
      return;
    }

    context.push('/placement/pdf-viewer', extra: {
      'title': material.title,
      'pdfUrl': material.fileUrl,
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String materialId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('This will permanently remove the material for all students.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(placementRepositoryProvider).deleteMaterial(materialId);
              ref.invalidate(courseMaterialsProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
