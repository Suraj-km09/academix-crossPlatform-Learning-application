Firebase Security Rules for student_hub

This document provides recommended Firebase Security Rules (Firestore + Storage) covering the app's main modules: users, notes, curriculum, bookmarks, admin/config, reports, colleges, bulletins, and storage objects. Treat these as a secure baseline—test in the emulator and adapt field names/indexes to your actual data model before deploying.

---

## Quick notes
- These rules assume user documents live in `users/{uid}` and include fields like `role`, `isBanned`, and `canUploadNotesPyqs`.
- App-level upload toggles are expected at `appConfig/security` under `uploadsAllowedForRoles` (legacy boolean or nested map). The Firestore rules consult that doc when present.
- Storage rules rely on object metadata for uploader ownership checks (recommended metadata key: `uploaderUid`). Storage rules cannot read Firestore documents, so you must ensure uploads set metadata appropriately.
- Always test rules locally with the Firebase Emulators before deploying.

---

## Firestore rules (recommended)

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helpers
    function isSignedIn() {
      return request.auth != null;
    }

    function userDoc(uid) {
      return get(/databases/$(database)/documents/users/$(uid)).data;
    }

    function isAdminUid(uid) {
      return userDoc(uid) != null && userDoc(uid).role == 'admin';
    }

    function isAdmin() {
      return isSignedIn() && isAdminUid(request.auth.uid);
    }

    // Check whether the current authenticated user is allowed to upload a resource.
    // It returns false if the user's profile disables uploads or the user is banned.
    // If `appConfig/security` exists and contains `uploadsAllowedForRoles`, this function
    // will respect role-level toggles when present.
    function canUploadResource(resource) {
      if (!isSignedIn()) { return false; }
      let u = userDoc(request.auth.uid);
      if (u == null) { return false; }
      if (u.isBanned == true) { return false; }
      if (u.canUploadNotesPyqs == false) { return false; }

      let secSnap = get(/databases/$(database)/documents/appConfig/security);
      if (!secSnap.exists) { return true; }
      let sec = secSnap.data;
      let uploads = sec.uploadsAllowedForRoles;
      if (uploads == null) { return true; }

      let roleEntry = uploads[u.role];
      // roleEntry may be a boolean (legacy) or a map { notes: bool, curriculum: bool }.
      // If roleEntry is missing, default to allowed.
      if (roleEntry == null) { return true; }
      if (roleEntry == true) { return true; }
      if (roleEntry == false) { return false; }

      let rflag = roleEntry[resource];
      return rflag == null || rflag == true;
    }

    // ------------------ users ------------------
    match /users/{userId} {
      allow read: if isSignedIn();

      // Users may create their own user doc (initial sign-up flow) and then
      // update allowed profile fields. Admins can update any user.
      allow create: if request.auth != null && request.auth.uid == userId;

      allow update: if isAdmin() || (
        request.auth != null && request.auth.uid == userId &&
        // Prevent regular users from escalating privileges or toggling server-managed flags
        !('role' in request.resource.data) &&
        !('isBanned' in request.resource.data) &&
        !('createdAt' in request.resource.data)
      );

      allow delete: if isAdmin();
    }

    // ------------------ notes ------------------
    // Document shape expected (example):
    // { uploadedBy: 'uid', collegeId: '...', title: '...', type: 'notes'|'pyq', isVerified: false, isRejected: false, uploadedAt: Timestamp }
    match /notes/{noteId} {
      // Public read (you may restrict to authenticated users if desired)
      allow read: if true;

      allow create: if canUploadResource('notes') &&
        request.resource.data.uploadedBy == request.auth.uid &&
        request.resource.data.collegeId is string &&
        request.resource.data.title is string &&
        request.resource.data.type in ['notes','pyq','faculty','sessional','put'];

      // Uploaders can update benign fields; admins can update verification/rejection flags.
      allow update: if isAdmin() || (
        request.auth != null && resource.data.uploadedBy == request.auth.uid &&
        // disallow uploader from changing ownership or moderation flags
        !('uploadedBy' in request.resource.data) &&
        !('isVerified' in request.resource.data) &&
        !('isRejected' in request.resource.data)
      );

      allow delete: if isAdmin() || (request.auth != null && resource.data.uploadedBy == request.auth.uid);
    }

    // ------------------ curriculum ------------------
    match /curriculum/{curriculumId} {
      allow read: if true;

      allow create: if canUploadResource('curriculum') &&
        request.resource.data.uploadedBy == request.auth.uid &&
        request.resource.data.collegeId is string &&
        request.resource.data.title is string;

      allow update: if isAdmin() || (
        request.auth != null && resource.data.uploadedBy == request.auth.uid &&
        // disallow changing ownership and moderation pins by non-admins
        !('uploadedBy' in request.resource.data)
      );

      allow delete: if isAdmin() || (request.auth != null && resource.data.uploadedBy == request.auth.uid);
    }

    // ------------------ bookmarks ------------------
    match /bookmarks/{bookmarkId} {
      allow read: if isSignedIn();
      allow create: if request.auth != null && request.resource.data.uid == request.auth.uid;
      allow delete: if isAdmin() || (request.auth != null && resource.data.uid == request.auth.uid);
      allow update: if false;
    }

    // ------------------ admin / config ------------------
    match /appConfig/{configId} {
      // Config is readable to authenticated users; modify only by admins.
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    // ------------------ admin logs ------------------
    match /adminLogs/{logId} {
      allow create: if isAdmin();
      allow read, update, delete: if isAdmin();
    }

    // ------------------ reports ------------------
    match /reports/{reportId} {
      allow create: if isSignedIn();
      allow read: if isAdmin() || (isSignedIn() && request.auth.uid == resource.data.reporterUid);
      allow update, delete: if isAdmin();
    }

    // ------------------ colleges ------------------
    match /colleges/{collegeId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isAdmin();
    }

    // ------------------ bulletins ------------------
    match /bulletins/{bulletinId} {
      allow read: if true;
      // Allow teachers and admins to create bulletins (if your app supports teacher posting)
      allow create: if isSignedIn() && (isAdmin() || userDoc(request.auth.uid).role == 'teacher');
      allow update: if isAdmin() || (isSignedIn() && resource.data.postedBy == request.auth.uid);
      allow delete: if isAdmin() || (isSignedIn() && resource.data.postedBy == request.auth.uid);
    }

    // Catch-all: deny anything else by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

> Important: Firestore rules above call `get()` against `users/{uid}` and `appConfig/security`. These reads have cost and are evaluated as part of rules enforcement. Keep the logic simple and test performance with the emulator.

---

## Storage rules (recommended)

Storage rules cannot read Firestore documents. To enforce ownership and safe deletes you must set and validate object metadata during uploads (recommended metadata keys: `uploaderUid`, `noteId` or `curriculumId`). The rules below use those conventions.

```rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Helpers
    function signedIn() { return request.auth != null; }
    // `admin` custom claim recommended to allow server/admin operations from privileged accounts.
    function isAdmin() { return request.auth != null && request.auth.token.admin == true; }

    // User profile photos
    match /users/{userId}/profile/{fileName} {
      allow read: if true; // Profiles are public - change to `signedIn()` if desired.
      allow write: if signedIn() && request.auth.uid == userId;
      allow delete: if signedIn() && (request.auth.uid == userId || isAdmin());
    }

    // Notes files. Enforce uploader metadata is set to authenticated uploader when writing.
    match /notes/{noteId}/{allPaths=**} {
      allow read: if true; // Public read; restrict to signed-in users if required.

      // Require uploaderUid metadata and that it matches the authenticated user.
      allow write: if signedIn() && request.resource != null &&
        request.resource.metadata.uploaderUid == request.auth.uid &&
        request.resource.metadata.noteId == noteId;

      // Delete allowed by uploader or admin.
      allow delete: if signedIn() &&
        (resource.metadata.uploaderUid == request.auth.uid || isAdmin());
    }

    // Curriculum files (same pattern as notes)
    match /curriculum/{curriculumId}/{allPaths=**} {
      allow read: if true;
      allow write: if signedIn() && request.resource != null &&
        request.resource.metadata.uploaderUid == request.auth.uid &&
        request.resource.metadata.curriculumId == curriculumId;
      allow delete: if signedIn() &&
        (resource.metadata.uploaderUid == request.auth.uid || isAdmin());
    }

    // Default: deny other storage paths
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

Notes for storage:
- Make sure upload clients (mobile/web) set `metadata: { uploaderUid, noteId }` when uploading files. Example (Web SDK):
  - `storageRef.put(file, { customMetadata: { uploaderUid: auth.uid, noteId } })`
- To allow server or admin accounts to bypass ownership checks, set a custom claim (e.g., `admin=true`) on the admin account via Firebase Admin SDK and check `request.auth.token.admin` in rules.

---

## Indexes & Firestore performance hints
- For server-side paging and prefix name search on users, add an indexed `nameLower` field to `users` (lowercased) so you can `orderBy('nameLower').startAt([query]).endAt([query + '\uf8ff'])` reliably.
- Index `notes.uploadedAt` and queries that filter by `collegeId` + `uploadedAt` or `collegeId` + `type` to support paged feeds.
- Use composite indexes for combined where+orderBy queries. The Firebase console will prompt for index creation when needed.

---

## Deployment & testing
- Run the emulator locally to test rules end-to-end before deploying:

```bash
firebase emulators:start --only firestore,storage
```

- When ready to deploy rules to production:

```bash
firebase deploy --only firestore:rules,storage:rules
```

---

## Final recommendations
- Keep rules minimal and well-tested. Prefer server-side admin operations (via Cloud Functions with admin privileges) for sensitive state transitions (e.g., promoting users, global toggles) to avoid complex rules logic and race conditions.
- Add automated rule tests using the Firebase Emulator and the `@firebase/rules-unit-testing` tooling or local integration tests in Dart/Flutter if you use integration test harnesses.

If you'd like, I can:
- Generate a Firestore rules file (`firestore.rules`) and Storage rules file (`storage.rules`) directly (ready to deploy), or
- Add emulator tests verifying the important flows (upload blocked/unblocked, storage metadata checks).


---

Generated on: 2026-04-06
