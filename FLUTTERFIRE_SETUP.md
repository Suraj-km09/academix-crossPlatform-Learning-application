# FlutterFire CLI Setup Guide (Windows)

This guide configures Firebase for the Flutter app in this project.

## Project Details

- Firebase project ID: academic-app-5b34a
- App folder: E:/academic_hub/student_hub
- Platforms: Android, iOS, Web

## 1) Open PowerShell In Project

```powershell
cd E:\academic_hub\student_hub
```

## 2) Verify Flutter And Dart

```powershell
flutter --version
dart --version
```

## 3) Install Firebase CLI (Node.js Required)

If Node.js is not installed, install Node.js LTS first.

```powershell
npm install -g firebase-tools
firebase --version
```

## 4) Install FlutterFire CLI

```powershell
dart pub global activate flutterfire_cli
```

If `flutterfire` is not recognized, add Dart pub cache to PATH for the current terminal:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
flutterfire --version
```

Optional (persistent PATH for your user):

```powershell
setx PATH "$($env:PATH);$env:LOCALAPPDATA\Pub\Cache\bin"
```

Close and reopen terminal after `setx`.

## 5) Login To Firebase

```powershell
firebase login
```

## 6) Configure Flutter App With Firebase

Run in project root:

```powershell
flutterfire configure --project=academic-app-5b34a --platforms=android,ios,web
```

This generates Firebase config files, including:

- lib/firebase_options.dart
- android/app/google-services.json
- ios/Runner/GoogleService-Info.plist

## 7) Update Firebase Initialization In main.dart

Ensure your `main.dart` includes:

- `import 'firebase_options.dart';`
- `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`

Example:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

## 8) Refresh Dependencies And Build

```powershell
flutter clean
flutter pub get
```

## 9) Run App And Verify Firebase Connection

```powershell
flutter run -d chrome
```

Or Android:

```powershell
flutter run -d android
```

If initialization succeeds and no Firebase config errors appear, setup is complete.

## 10) Common Troubleshooting

### A) `flutterfire` command not found

- Re-run PATH command in Step 4
- Restart terminal
- Run `flutterfire --version`

### B) Firebase initialization fails at runtime

- Confirm `lib/firebase_options.dart` exists
- Confirm `main.dart` uses `DefaultFirebaseOptions.currentPlatform`
- Re-run `flutterfire configure`

### C) Android build does not detect Firebase config

- Confirm `android/app/google-services.json` exists
- Ensure package ID in Firebase matches app ID in Android config

### D) iOS config issues

- Confirm `ios/Runner/GoogleService-Info.plist` exists
- On macOS, run `cd ios; pod install`

## 11) After Setup (Recommended)

- Enable Firebase Authentication providers you need
- Create Firestore database
- Add initial `colleges` documents
- Configure Firestore and Storage security rules
