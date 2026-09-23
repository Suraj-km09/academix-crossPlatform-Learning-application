import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/storage_bucket_config.dart';

class StorageImageCacheService {
  StorageImageCacheService._();

  static const String _boxName = 'storage_image_url_cache';
  static final Map<String, String> _memoryCache = <String, String>{};
  static final Map<String, Future<String?>> _inFlight =
      <String, Future<String?>>{};
  static Future<Box<String>>? _boxFuture;

  static String? peekResolvedDownloadUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final memoryHit = _memoryCache[value];
    if (memoryHit != null && memoryHit.isNotEmpty) {
      return memoryHit;
    }

    return null;
  }

  static Future<String?> resolveDownloadUrl(String pathOrUrl) async {
    final value = pathOrUrl.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final memoryHit = _memoryCache[value];
    if (memoryHit != null && memoryHit.isNotEmpty) {
      return memoryHit;
    }

    final pending = _inFlight[value];
    if (pending != null) {
      return pending;
    }

    final future = _resolveDownloadUrlInternal(value);
    _inFlight[value] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(value);
    }
  }

  static Future<String?> _resolveDownloadUrlInternal(String value) async {
    final memoryHit = _memoryCache[value];
    if (memoryHit != null && memoryHit.isNotEmpty) {
      return memoryHit;
    }

    try {
      final box = await _openBox();
      final cached = box.get(value);
      if (cached != null && cached.isNotEmpty) {
        _memoryCache[value] = cached;
        return cached;
      }
    } catch (_) {
      // Ignore cache read failures and fallback to Firebase Storage.
    }

    try {
      final resolved = await FirebaseStorage.instanceFor(
        bucket: StorageBucketConfig.activeBucketGsUri,
      ).ref(value).getDownloadURL();
      _memoryCache[value] = resolved;

      try {
        final box = await _openBox();
        await box.put(value, resolved);
      } catch (_) {
        // Ignore cache write failures; resolved URL is still returned.
      }

      return resolved;
    } catch (_) {
      return null;
    }
  }

  static Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }

    final pending = _boxFuture;
    if (pending != null) {
      return pending;
    }

    final future = Hive.openBox<String>(_boxName);
    _boxFuture = future;

    try {
      return await future;
    } finally {
      if (!Hive.isBoxOpen(_boxName)) {
        _boxFuture = null;
      }
    }
  }

  /// Invalidate any cached resolved download URL or image cache entry related
  /// to the provided storage path or resolved URL. This removes any in-memory
  /// and on-disk (Hive) cache entries, cancels in-flight lookups, and
  /// attempts best-effort eviction from the Flutter image caches.
  static Future<void> invalidateResolvedDownloadUrl(String pathOrUrl) async {
    final value = pathOrUrl.trim();
    if (value.isEmpty) return;

    // Remove any in-memory mapping keyed by the exact value.
    _memoryCache.remove(value);

    // Remove any in-flight lookups for the value.
    _inFlight.remove(value);

    try {
      final box = await _openBox();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        // If the caller passed a resolved URL, remove any storage-path keys
        // that map to this URL so subsequent resolves re-fetch from storage.
        final keysToRemove = <String>[];
        for (final k in box.keys.cast<String>()) {
          final stored = box.get(k);
          if (stored == value) keysToRemove.add(k);
        }
        for (final k in keysToRemove) {
          await box.delete(k);
          _memoryCache.remove(k);
        }
      } else {
        // Treat value as a storage path key and remove its cached resolved URL.
        await box.delete(value);
      }
    } catch (_) {
      // Ignore cache store errors; we still try to evict image caches below.
    }

    // Best-effort: evict any in-memory image cache entries for this URL.
    try {
      if (value.startsWith('http://') || value.startsWith('https://')) {
        try {
          final provider = NetworkImage(value);
          await provider.evict();
        } catch (_) {}

        try {
          await CachedNetworkImage.evictFromCache(value);
        } catch (_) {}
      }
    } catch (_) {
      // Swallow any image cache eviction failures.
    }
  }
}
