import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});
