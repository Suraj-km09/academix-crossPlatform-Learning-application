import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_image_cache_service.dart';

final resolvedStorageUrlProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, pathOrUrl) async {
      final value = pathOrUrl.trim();
      if (value.isEmpty) return null;

      final peek = StorageImageCacheService.peekResolvedDownloadUrl(value);
      if (peek != null) return peek;

      return await StorageImageCacheService.resolveDownloadUrl(value);
    });
