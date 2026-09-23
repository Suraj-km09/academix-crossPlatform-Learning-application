import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/note_model.dart';
import '../data/notes_repository.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});

final notesFutureProvider = FutureProvider.family<List<NoteModel>, String>((
  ref,
  collegeId,
) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getNotes(collegeId: collegeId);
});

final recentNotesStreamProvider =
    StreamProvider.family<
      List<NoteModel>,
      ({
        String collegeId,
        int limit,
        String? type,
        String? uploadedBy,
        String? course,
        String? branch,
      })
    >((ref, params) {
      final repository = ref.watch(notesRepositoryProvider);
      return repository.getRecentNotes(
        params.collegeId,
        limit: params.limit,
        type: params.type,
        uploadedBy: params.uploadedBy,
        course: params.course,
        branch: params.branch,
      );
    });

final pendingNotesProvider = FutureProvider.family<List<NoteModel>, String>((
  ref,
  collegeId,
) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getPendingNotes(collegeId);
});

final bookmarksProvider = FutureProvider.family<List<NoteModel>, String>((
  ref,
  uid,
) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getBookmarks(uid);
});

final noteByIdProvider = FutureProvider.family<NoteModel?, String>((
  ref,
  noteId,
) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getNoteById(noteId);
});
