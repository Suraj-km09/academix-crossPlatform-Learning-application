import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../models/academic_options_model.dart';

final academicOptionsProvider = StreamProvider<AcademicOptionsModel>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestorePaths.appConfig)
      .doc('academic_options')
      .snapshots()
      .map((doc) => AcademicOptionsModel.fromMap(doc.data()));
});
