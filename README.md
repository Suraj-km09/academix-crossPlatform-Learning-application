# 🎓 Academix — Cross-Platform Learning & Academic Management System

<p align="center">
  <img src="assets/images/academix_logo.png" alt="Academix Logo" width="120" height="120" />
</p>

<p align="center">
  <strong>The all-in-one digital campus ecosystem connecting Students, Educators, Alumni, and Administrators.</strong>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"></a>
  <a href="https://firebase.google.com"><img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black" alt="Firebase"></a>
  <a href="https://riverpod.dev"><img src="https://img.shields.io/badge/State%20Management-Riverpod%202.x-blueviolet" alt="Riverpod"></a>
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS-success" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
</p>

---

## 🌟 Overview

**Academix** is an enterprise-grade, cross-platform academic super-app designed to unify higher education management and campus life. From real-time college communications and curriculum tracking to intelligent peer note-sharing, AI study companions, placement preparation, and direct alumni mentorship—Academix replaces fragmented tools with a seamless, responsive, and secure experience on mobile, web, and desktop.

---

## 🚀 Core Features

### 📚 Academics & Notes Hub
- **Peer-to-Peer Note Sharing:** Upload and discover lecture notes, slides, and study guides filtered by college, department, subject, and semester.
- **Embedded PDF Engine:** High-performance in-app PDF viewing powered by Syncfusion with instant search, zoom, and page navigation.
- **Offline Access:** Powered by Hive local database caching for uninterrupted studying anywhere, anytime.
- **Quality & Moderation:** Community ratings, teacher endorsements, and an administrative review workflow for uploaded content.

### 🤖 Academix AI Suite
- **AI Study Copilot:** Context-aware academic assistant to summarize dense study material, explain complex formulas, and answer conceptual questions.
- **Personalized Roadmaps:** Dynamic, role-based learning tracks for software engineering, data science, core engineering, and competitive exams.
- **Skill Gap Analyzer:** Benchmarks student skills against real-world industry requirements and generates custom remediation plans.

### 💼 Placement & Career Accelerator
- **Curated DSA Sheet:** Topic-wise Data Structures & Algorithms question bank with difficulty tiers, solutions, and completion tracking.
- **Placement Materials & Insights:** Company-specific interview experiences, coding interview PDFs, and placement guides.
- **Interactive MCQ Engine:** Time-bound practice tests with detailed explanations, scoring analytics, and review modes.

### 📄 ATS Resume Studio
- **Guided Resume Builder:** Step-by-step form tailored for university students and new grads (education, projects, internships, leadership).
- **Industry Templates:** Clean, ATS-compliant designs that stand out to technical recruiters.
- **One-Click PDF Export:** Compile and export vector-quality PDFs directly from the app.

### 🔒 Digital Academic Locker
- **Encrypted Document Vault:** Secure personal cloud storage for degree certificates, semester marksheets, ID cards, and letters of recommendation.
- **Fast Search & Preview:** Instant categorization, metadata tagging, and built-in document preview.

### 💬 Campus Connect & Real-Time Chat
- **1-on-1 & Group Messaging:** Instant messaging between classmates, study groups, and project teams.
- **Presence & Delivery:** Live presence indicators, message read receipts, and typing awareness.
- **FCM Push Notifications:** Background notifications via Firebase Cloud Messaging for urgent updates.

### 📢 Smart Digital Bulletin
- **Targeted Announcements:** Official university circulars, exam notifications, and department updates.
- **Role & Branch Filters:** Content targeted to specific departments, years, or roles (Students, Teachers, Alumni).

### 🤝 Alumni & Mentorship Network
- **Alumni Directory:** Search graduates by company, graduation year, industry, and role.
- **Job & Referral Hub:** Direct referral requests to alumni with resume attachments and status tracking.
- **Alumni Q&A Forum:** Public mentorship channels for career advice and industry guidance.

### 🛡️ Administrative Command Center
- **Teacher Verification & Approval:** Secure workflow for verifying teacher registrations and assigning permissions.
- **User Management & Audit Logs:** Centralized control over roles, bans, access privileges, and security audit logs.
- **Curriculum & College Management:** Add and update college lists, branches, subjects, and academic calendars.

---

## 🛠️ Architecture & Tech Stack

```
academix-crossPlatform-Learning-application/
├── android/            # Android native project files & Gradle scripts
├── ios/                # iOS native project files & Xcode workspace
├── web/                # Web entry point, manifest, and icons
├── windows/            # Windows desktop C++ runner & CMake configuration
├── macos/              # macOS desktop runner
├── linux/              # Linux desktop runner
├── functions/          # Firebase Cloud Functions (Node.js v2)
├── lib/
│   ├── core/           # Constants, themes, routes (GoRouter), utilities
│   ├── features/       # Feature-driven modular architecture
│   │   ├── admin/      # Management, verification & moderation panels
│   │   ├── ai/         # AI Copilot, roadmaps, and skill gap tools
│   │   ├── alumni/     # Directory, Q&A, and referral systems
│   │   ├── auth/       # Authentication, onboarding, roles & splash
│   │   ├── bulletin/   # Campus announcements and news feed
│   │   ├── chat/       # Real-time messaging, group chat & presence
│   │   ├── curriculum/ # Syllabi, branches, and semester plans
│   │   ├── home/       # Role-adaptive dashboards & widgets
│   │   ├── locker/     # Personal document storage & locker
│   │   ├── notes/      # Note discovery, upload & PDF viewer
│   │   ├── notifications/# In-app alerts and notification center
│   │   ├── placement/  # DSA tracker, MCQs, interview guides
│   │   ├── profile/    # User settings and academic profiles
│   │   └── resume/     # ATS builder, template selector & PDF exporter
│   ├── shared/         # Common widgets, base models, and services
│   └── main.dart       # App initialization, Firebase setup & runner
└── assets/             # Branding assets, templates, college database
```

| Layer | Technologies |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) (v3.x / Dart 3.x) |
| **State Management** | [Flutter Riverpod](https://riverpod.dev) + `riverpod_annotation` & `build_runner` |
| **Routing** | [GoRouter](https://pub.dev/packages/go_router) (Declarative, deep-link ready) |
| **Backend & Auth** | [Firebase Authentication](https://firebase.google.com/products/auth), [Cloud Firestore](https://firebase.google.com/products/firestore) |
| **Cloud Storage** | [Firebase Storage](https://firebase.google.com/products/storage) |
| **Serverless Logic**| [Cloud Functions v2](https://firebase.google.com/products/functions) (Node.js) |
| **Push Notifications**| [Firebase Cloud Messaging](https://firebase.google.com/products/cloud-messaging) + [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| **Security & Integrity**| [Firebase App Check](https://firebase.google.com/products/app-check) (Play Integrity / App Attest) |
| **Local Cache** | [Hive Flutter](https://pub.dev/packages/hive_flutter) + [SharedPreferences](https://pub.dev/packages/shared_preferences) |
| **Document Processing**| [Syncfusion Flutter PDF](https://pub.dev/packages/syncfusion_flutter_pdfviewer), `pdf`, `printing` |
| **Monetization** | [Google Mobile Ads SDK](https://developers.google.com/admob) |

---

## ⚡ Getting Started

### Prerequisites

Ensure you have installed:
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.11+ recommended)
- [Dart SDK](https://dart.dev/get-dart)
- [Node.js & npm](https://nodejs.org/) (for Cloud Functions & Firebase CLI)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Platform tools: Android Studio / Xcode / Visual Studio (C++ Desktop development for Windows)

### 1. Clone the Repository

```bash
git clone https://github.com/Suraj-km09/academix-crossPlatform-Learning-application.git
cd academix-crossPlatform-Learning-application
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Make sure your Firebase project is linked:

```bash
# Log in to your Firebase account
firebase login

# Configure platforms with FlutterFire CLI
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

*(Note: See [FLUTTERFIRE_SETUP.md](FLUTTERFIRE_SETUP.md) for full Windows environment configuration instructions).*

### 4. Setup Cloud Functions (Optional / Backend)

```bash
cd functions
npm install
firebase deploy --only functions
cd ..
```

### 5. Generate Code (Riverpod / Hive)

If you modify models or state annotations:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 6. Run the App

Select your target device or emulator and run:

```bash
# Run on connected phone / emulator
flutter run

# Run on Windows Desktop
flutter run -d windows

# Run on Chrome
flutter run -d chrome
```

---

## 🔐 Security & Best Practices

- **App Check Activated:** Firebase App Check is enabled out of the box using Play Integrity (Android) and App Attest (iOS/macOS) to prevent unauthorized API requests and bot traffic.
- **Granular Security Rules:** Production-hardened [Firestore Rules](firestore.rules) and [Storage Rules](storage.rules) enforce strict role-based access control (RBAC).
- **Session Guards:** Secure authentication lifecycle management with automated session clearance on sensitive builds.
- **Write Rate Limiting:** Client-side rate limiting on high-frequency operations prevents database abuse.

---

## 🤝 Contributing

Contributions make the open-source community an inspiring place to learn, inspire, and create! Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

<p align="center">
  Built with ❤️ for students, educators, and lifelong learners.
</p>
