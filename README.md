# Orion Beast FX — Android EA notification receiver

**Source project, not a compiled APK.** This project has not been compiled or tested on an Android device in the authoring environment, which has no Android SDK or Java. It does not execute trades.

## Configuration
- Server: https://ntfy.sh (HTTPS only)
- Default topic: OrionBeastFx (case-sensitive)
- Subscription stream: https://ntfy.sh/OrionBeastFx/json
- Android 8.0 or newer (API 26); compile/target SDK 35.
- Uses native Android Java APIs; no third-party runtime dependencies.

## Generate the APK using GitHub (no computer SDK required)
1. Create a GitHub repository you control.
2. Extract this ZIP and upload the CONTENTS of the OrionBeastFx folder to the repository root. Include the hidden .github folder and all app subfolders. Do not upload only the ZIP.
3. Open the repository Actions tab. Enable workflows if prompted. Select “Build Orion Beast FX APK” and “Run workflow” on your branch. The push trigger also runs on main/master.
4. Wait for a green build. If it fails, inspect the logs; no APK exists unless the build succeeds.
5. In the completed run, download the artifact “OrionBeastFx-debug-APK”. Extract it to get app-debug.apk.
6. On your Android phone, open the APK and allow installation from that download/browser source if Android requests it. Only install artifacts from your own trusted repository. Disable that installation permission afterward if desired.

This produces an automatically debug-signed sideload APK, not a production/store release. GitHub build environments may use different debug signing keys: a later debug build may not update an earlier install without uninstalling it (which removes local history). Use a private stable release key for durable production updates. Do not share signing secrets in your repository.

## Generate locally instead
Install Android Studio, open this folder, let Gradle sync with JDK 17 and Android SDK 35, then use Build > Build APK(s). Alternatively, with Gradle 8.9 and the Android SDK installed, run `gradle :app:assembleDebug`. Output: app/build/outputs/apk/debug/app-debug.apk. A Gradle wrapper is not included; Android Studio or the supplied workflow provides Gradle.

## Use
1. Install and open Orion Beast FX.
2. Keep topic OrionBeastFx, or change it to EXACTLY match your EA publisher.
3. Tap Start receiving alerts and grant notification permission on Android 13+.
4. Leave the ongoing receiver notification enabled. Alerts appear in the phone notification shade and the app inbox (latest 100 messages).
5. To change topics, tap Stop, edit the topic, then Start. To stop listening, use the app Stop button or the ongoing notification Stop action.
6. Your EA must already publish message bodies to https://ntfy.sh/OrionBeastFx. In MetaTrader, enable WebRequest for https://ntfy.sh if your EA uses WebRequest. The receiver cannot modify or verify your EA configuration.

## Verify end to end
After building/installing, publish a test message yourself to the topic from your EA or a trusted ntfy client. Confirm that the notification and inbox both show it with the app open, in the background, with the screen off, and after a temporary network loss. No test message was sent during project creation. A public topic may have other subscribers.

## Security and operating limits
- Public ntfy topics are NOT private or authenticated signals. Anyone who knows or guesses the topic can potentially read or publish messages. Never send trading passwords, account credentials or personal information. Use a long random topic and, for stronger security, a protected ntfy deployment/account with authentication (not implemented in this version).
- This is a receiver only. It does not parse trade instructions, connect to a broker or place orders. It displays the EA message verbatim and does not prove the sender's identity.
- Uses a user-started special-use foreground service and a persistent notification for background streaming. A Play Store release would require foreground-service declaration/review and any other applicable store requirements; approval is not implied.
- No Firebase, no wake lock, no boot auto-start, and no automatic exemption from battery optimization. Android Doze, manufacturer battery controls, force-stop, reboot, revoked notification permission, outages, network restrictions and ntfy retention/rate limits can delay or prevent alerts. Start again after reboot/force-stop. It is not a guaranteed real-time trading system.
- First start listens from the current time; later reconnects use the last received message ID and ntfy's available cached history. Expired server history cannot be recovered. A process crash at notification/history persistence boundaries can cause a duplicate; exactly-once delivery is not promised.
- Alerts use a high-importance channel with sound/vibration controlled by Android notification settings and Do Not Disturb. ntfy priority, attachments, action buttons and authentication are not implemented.
- Inbox stays on the phone, Android backup is disabled, and alerts hide detailed content on the lock screen unless device settings override it.

## Validation status
Authoring checks: XML parsing, required source files/configuration, archive integrity. NOT verified: Java compilation, Gradle dependency resolution, APK signing/install, foreground-service behavior, ntfy live connection, or device notifications. Complete the end-to-end checks above before relying on this app.
