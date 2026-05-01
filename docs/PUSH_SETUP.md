# Push Notification Setup

Silent wake-only push notifications are used to wake the app when messages arrive
for offline users.  **No message content, sender name, or count is ever sent to
Apple or Google servers.**  The payload contains only a wake signal; the app then
opens a WebSocket and drains `GET /messages/pending`.

---

## Android (FCM)

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Add an Android app with package name matching `client/android/app/build.gradle`
   (`applicationId`).
3. Download `google-services.json` and place it at `client/android/app/google-services.json`.
4. In Firebase console → Project Settings → Cloud Messaging, copy the **Server key**.
5. Set `FCM_SERVER_KEY=<your-server-key>` in `infra/.env`.

---

## iOS (APNs via Firebase)

1. In the same Firebase project, add an iOS app with your bundle ID.
2. Download `GoogleService-Info.plist` and place it at
   `client/ios/Runner/GoogleService-Info.plist`.
3. In Apple Developer portal → Certificates, Identifiers & Profiles:
   - Enable **Push Notifications** for your App ID.
   - Create an **APNs Auth Key** (`.p8`).  Note the Key ID and Team ID.
4. Upload the `.p8` key in Firebase console → Project Settings → Cloud Messaging →
   Apple app configuration.
5. Set the following in `infra/.env`:
   ```
   APNS_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
   APNS_KEY_ID=XXXXXXXXXX
   APNS_TEAM_ID=YYYYYYYYYY
   APNS_BUNDLE_ID=com.example.cryptochatapp
   ```

---

## Important: Files not committed to git

`google-services.json` and `GoogleService-Info.plist` contain project-specific
credentials and **must not be committed**.  They are listed in `.gitignore`.
Each developer and the CI/CD environment must obtain their own copy.

---

## Privacy notes

- The FCM payload is `{"to":"<token>","data":{"wake":"1"}}` — no `notification` key.
- The APNs payload is `{"aps":{"content-available":1}}` with `apns-push-type: background`
  and `apns-priority: 5`.
- Push permission is requested with `alert: false, badge: false, sound: false,
  provisional: true` — no permission dialog is shown on iOS.
