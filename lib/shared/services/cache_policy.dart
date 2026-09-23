class CachePolicy {
  CachePolicy._();

  // Guard against repeated pull-to-refresh calls causing duplicate network reads.
  static const Duration manualRefreshMinInterval = Duration(seconds: 30);

  // Keep profile data relatively fresh while avoiding repeated reads.
  static const Duration userProfileMaxAge = Duration(minutes: 10);

  // Locker file metadata changes less frequently for most users.
  static const Duration lockerFilesMaxAge = Duration(minutes: 5);

  // Notifications should feel fresh, but can still benefit from short-term cache.
  static const Duration notificationsMaxAge = Duration(minutes: 2);

  // Bulletin board content can tolerate moderate cache windows.
  static const Duration bulletinsMaxAge = Duration(minutes: 5);
}
