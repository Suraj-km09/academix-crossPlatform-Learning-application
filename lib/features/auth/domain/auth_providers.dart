import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../shared/models/user_model.dart';
import '../data/auth_repository.dart';
import '../data/colleges_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(auth: ref.watch(firebaseAuthProvider));
});

final collegesRepositoryProvider = Provider<CollegesRepository>((ref) {
  return CollegesRepository();
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Indicates if the core app initialization (Hive, services) is complete.
final isAppReadyProvider = StateProvider<bool>((ref) => false);

final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection(FirestorePaths.users)
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null);
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection(FirestorePaths.users)
      .doc(user.uid)
      .get();

  return doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null;
});

final otherUserProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance
      .collection(FirestorePaths.users)
      .doc(uid)
      .get();

  return doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null;
});

String dashboardRouteForRole(String role) {
  return '/home';
}
