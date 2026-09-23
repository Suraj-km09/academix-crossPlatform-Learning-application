import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kReleaseMode, kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:syncfusion_flutter_core/core.dart';

import 'firebase_options.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/firestore_paths.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/ad_service.dart';
import 'shared/services/auth_session_service.dart';
import 'shared/services/fcm_service.dart';
import 'shared/services/theme_mode_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Critical early initialization
  await Hive.initFlutter();

  // Background service initializations (non-blocking)
  unawaited(_activateFirebaseAppCheck());
  unawaited(FCMService.setupBackgroundHandler());
  unawaited(FCMService.initFCM());
  unawaited(AdService.initAds());
  unawaited(AuthSessionService.start());
  unawaited(FirebaseAuth.instance.setLanguageCode('en'));

  // Register Syncfusion license
  SyncfusionLicense.registerLicense(
    'Ngo9BigBOggjHTQxAR8/V1JHaF5cWWdCf1FpRmJGdld5fUVHYVZUTXxaS00DNHVRdkdlWXted3RcQ2hYUEB0XkpWYEo=',
  );

  try {
    if (defaultTargetPlatform == TargetPlatform.windows && kReleaseMode) {
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        final doc = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(current.uid)
            .get();
        final role =
            (doc.data()?['role'] as String?)?.toLowerCase() ?? 'student';
        if (role == 'admin') {
          await FirebaseAuth.instance.signOut();
          debugPrint('Cleared admin session on Windows release build');
        }
      }
    }
  } catch (e) {
    debugPrint('Admin session guard failed: $e');
  }

  runApp(const ProviderScope(child: StudentHubApp()));
}

Future<void> _activateFirebaseAppCheck() async {
  try {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
        break;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        await FirebaseAppCheck.instance.activate(
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttest,
        );
        break;
      default:
        break;
    }
  } catch (_) {}
}

class StudentHubApp extends ConsumerStatefulWidget {
  const StudentHubApp({super.key});

  @override
  ConsumerState<StudentHubApp> createState() => _StudentHubAppState();
}

class _StudentHubAppState extends ConsumerState<StudentHubApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      unawaited(FCMService.setupInteractionHandler(router));
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
