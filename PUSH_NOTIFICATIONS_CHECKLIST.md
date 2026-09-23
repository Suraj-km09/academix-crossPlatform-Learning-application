# Push Notifications Checklist

## What is already implemented in code

- FCM token sync to `users.fcmToken` from app startup.
- Firebase Messaging foreground/background/open handlers in Flutter app.
- Cloud Functions send notification docs + FCM push for:
  - New referral request
  - Referral accepted/rejected
  - New chat message
  - New bulletin
  - Note verified/rejected
  - New alumni question
  - Alumni answer posted
- Android 13+ runtime permission declaration:
  - `android.permission.POST_NOTIFICATIONS` in main manifest.

## iOS manual setup (required)

Apply these once in Xcode for the `Runner` target:

1. Signing & Capabilities
- Add capability: `Push Notifications`
- Add capability: `Background Modes`
- Enable: `Remote notifications` under Background Modes

2. APNs key/certificate
- In Apple Developer account, ensure APNs key/cert is configured for the app bundle ID.

3. Firebase Cloud Messaging iOS mapping
- In Firebase Console > Project Settings > Cloud Messaging, upload APNs auth key if not already set.

4. Validate generated entitlements
- Ensure Runner entitlements include `aps-environment`.

## Deployment reminders

1. Deploy Cloud Functions after code changes
- `cd functions`
- `npm install`
- `firebase deploy --only functions`

2. Install latest app build on test devices after manifest/permission changes.

## Real-time test matrix

Use two real devices and two accounts (sender and receiver). Keep receiver app closed for closed-app validation.

1. Chat
- Sender sends direct message.
- Expected: receiver gets push, tapping opens chat route.

2. Referrals
- Student sends referral request.
- Expected: alumni receives push.
- Alumni accepts/rejects.
- Expected: student receives push.

3. Alumni Q&A
- Student asks question.
- Expected: alumni receives push.
- Alumni answers.
- Expected: student receives push.

4. Bulletin
- Teacher/admin posts bulletin for receiver audience.
- Expected: receiver gets push to bulletin detail.

5. Note moderation
- Admin verifies/rejects note.
- Expected: uploader receives push to note detail.

## Known behavior

- Notification records are now created by Cloud Functions for the above events to avoid duplicate entries.
- If a user has no valid `fcmToken`, the notification document may still be created, but push cannot be delivered.
