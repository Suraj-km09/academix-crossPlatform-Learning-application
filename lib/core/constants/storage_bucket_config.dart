class StorageBucketConfig {
  StorageBucketConfig._();

  static const String activeBucketName =
      'academic-app-5b34a.firebasestorage.app';

  static String get activeBucketGsUri => 'gs://$activeBucketName';
}
