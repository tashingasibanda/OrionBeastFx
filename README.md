# OrionBeastFx v4 — Home layout update

**This archive is Android source code, NOT an installable APK.** Build using the included GitHub Actions workflow, then install the APK from its successful build artifact. The source layout was browser-tested; Android compilation and phone notification delivery were not verified here. Android 8.0 or newer is required (minSdk 26).

## Home actions
- Trade opens received EA alerts in Trader; it does not place orders.
- Quotes explains that no quote feed is connected and links to EA Watch/Standby symbols.
- Analyzer opens Symbols. History shows received messages.
- AI Chat clearly reports that no AI provider is connected; AI Insight describes received data only.
- Remove asks before closing this phone's receiver connection; it does not delete saved data or remove an EA from MetaTrader.
- Bot Stopped describes the phone receiver. CONNECTED reflects the actual ntfy stream.
- New installs default to dark mode; existing saved preferences remain unchanged.

## Building and installing
1. Extract the archive and upload the contents of the OrionBeastFx folder (including .github) to the repository root.
2. Run Actions > Build OrionBeastFx APK > Run workflow.
3. Download the OrionBeastFx-debug-APK artifact after the build succeeds. Extract it and install app-debug.apk, not this project ZIP.
4. Allow installation from your browser/file manager when Android requests it.
5. If installation fails, keep the previous app and capture the exact Android error. An incompatible signing key can prevent updates; do not uninstall without backing up data and understanding data loss.

---
Previous project documentation (some Home layout descriptions below are superseded by v4):

# OrionBeastFx Android v3

An Android ntfy trading-alert receiver with an offline bundled SVG interface.
Defaults: server https://ntfy.sh, topic OrionBeastFx. Both remain editable.

## Build the APK
1. Extract this ZIP. Upload the CONTENTS of OrionBeastFx/ to a GitHub repository root (including .github/).
2. Open Actions > Build OrionBeastFx APK > Run workflow.
3. After a successful run download OrionBeastFx-debug-APK, extract it, and install app-debug.apk on Android 8+.
4. Allow notifications and select START LIVE. Keep battery restrictions in mind.

The debug APK is for testing. Use your own release keystore for production. To update an already installed build, retain the same signing key; GitHub fresh runners may generate different debug keys, requiring an uninstall (which removes saved data) before installation. Back up needed data before uninstalling. No APK is bundled here: Android compilation and on-device delivery have not been verified in this environment.

Local build with JDK 17, Android SDK platform/build-tools 35 and Gradle 8.9:
    gradle --no-daemon :app:testDebugUnitTest :app:assembleDebug

## v3 interface
- Correct OrionBeastFx launcher title, header and receiver notification branding.
- Fixed bundled chart/lion artwork. Image picker removed.
- SVG icon navigation and toolbar. Navigation has 16 CSS pixel side/bottom gaps, 24px radius and a shadow inside the app safe area.
- Green STOP LIVE when receiver runs; red START LIVE when stopped. These control reception, never EA execution.
- Dark Mode in Settings, persisted through native SharedPreferences across reloads/restarts. Dark background #121212, cards/bar #1E1E1E.
- Real summary data only: trades, win_rate, net_r (shown in R units). Missing metrics are dashes.
- Receiver connection is separate from last structured EA update and staleness.
- Terminal groups actual symbol messages into Watch and Standby; no inferred or sample symbols.
- History displays the latest 300 saved messages. Signal excludes successfully parsed state traffic.
- AI Insight transparently reports that no AI provider is connected, and shows only received-data observations.
- Settings retain editable HTTPS server, topic, access token and stale threshold (30-86400 seconds).

## EA integration
See EA-INTEGRATION.md. Existing message formats, reducer and foreground receiver are retained. EA source was not supplied and is not modified. The interface runs in a restricted local WebView; native Android service handles ntfy and phone notifications even when the UI is closed. OS force-stop, battery restrictions or network loss may interrupt reception.

## Security
A public ntfy topic is readable/publishable by others; it is not an authenticated trading feed. Use a protected server/topic/token for private alerts. Tokens are stored in app-private preferences, not encrypted storage; Android backup is disabled. Untrusted EA message content is displayed as text, not HTML. No trading orders are sent.
