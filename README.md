# Star Beast FX Android receiver — ivory edition v2

Native Android source project, updated from the Orion Beast FX project. This ZIP is NOT an APK.

## Build an installable APK
1. Extract this ZIP. Upload the CONTENTS of the `OrionBeastFx` folder to your GitHub repository root, including `.github`.
2. Open Actions → Build Star Beast FX APK → Run workflow.
3. The workflow runs reducer unit tests, then builds a debug APK. Download `StarBeastFx-debug-APK`, extract it and install `app-debug.apk`.
4. Allow notifications. Open Settings to set server/topic/token, then Start receiver. Android may ask permission to install unknown apps from your download app.

Requires JDK 17, Gradle 8.9, Android SDK 35. Local command: `gradle :app:testDebugUnitTest :app:assembleDebug`.
Debug builds use a development signing key. A later build may not update an existing install if signed with a different key; use a stable release signing key for upgrades. Uninstalling deletes local data.

## What changed
- Ivory/gold native interface inspired by your image: lion, chart artwork, Home / Signal / Terminal / Settings and Change Image.
- Terminal is NOT a command console. It groups EA-reported symbols into On Watch and On Standby, with timeframe, reason, last update and stale indicator.
- No sample symbols, trades, win rate or P/L in the running app. Empty data stays empty/—. Summary numbers require a valid EA summary for today's PHONE-local date. P/L is R units only; currency is not mixed into R.
- Configurable HTTPS ntfy server, topic and optional Bearer token. The supplied defaults are https://ntfy.sh and OrionBeastFx, not locked settings.
- Start Live uses ntfy's persistent HTTP JSON stream, NOT a WebSocket. The label intentionally says Live rather than WS.
- History includes all received messages; Signal shows plain alerts and rejected structured messages. Up to 300 messages per configured server/topic. Terminal state and day summaries persist separately.
- AI Insight is explicitly unconfigured; it does NOT fabricate model output or give fake trading advice.

## Important: EA integration is required
Read EA-INTEGRATION.md. Existing plain text notifications continue to work, but watch/standby cannot be inferred reliably from arbitrary prose. Your EA must send JSON in its ntfy message body. The EA source was not supplied and has NOT been modified.

## Delivery, safety and privacy
- Public topics are not private or authenticated; anyone who knows the topic may read/publish. Use a protected ntfy server/account/topic and token for private data.
- Tokens are saved in app-private SharedPreferences, not encrypted with Android Keystore. Android backup is disabled. Use device encryption/lock, do not use a rooted/shared device for sensitive tokens.
- No broker connection, auto-trading, trade placement or promised profits.
- Connected means ntfy stream connected, NOT proof your EA is alive. Terminal displays last received server timestamp; after 300 seconds by default it is marked stale. Change threshold in Settings. EA timestamps in the message are not used; ntfy envelope time is used.
- User-started foreground service with ongoing notification. No boot auto-start, no wake lock and no guaranteed delivery under Doze, force-stop, reboot, battery optimization or network loss. Restart manually after reboot/force-stop. Play Store foreground-service review may be required.
- First listen starts now; reconnect resumes from last saved ntfy ID within available server retention. Send snapshots regularly and after starting a new phone; no old state appears automatically without messages.
- Same endpoint/topic state is restored; a different endpoint/topic has a separate cache. Stop receiver before changing connection. Multiple EAs publishing the same symbol share one symbol row: use separate topics or aggregate states upstream.

## Verification status
Archive integrity, Android XML and static source/configuration checks were performed during authoring. Reducer JUnit tests are included and configured to run in CI, but were NOT executed here. No Java/Gradle/Android SDK was available here: compilation, APK installation, on-phone appearance, background execution and live ntfy delivery remain UNVERIFIED. Build and test on a device before relying on alerts.

## Device acceptance checklist
- Build succeeds and all reducer tests pass.
- Fresh install: no fake symbols or performance metrics.
- Allow notifications; Start Live changes from Connecting to Connected against your server.
- Publish actual EA watch/standby messages: Terminal updates, reason/timeframe visible.
- Transition a symbol watch → standby → remove; send an empty snapshot to clear list.
- Plain message triggers phone notification and appears in Signal. Structured state/summary/heartbeat traffic is silent.
- Today's summary appears from a valid JSON summary; absent fields show —. Previous dates do not appear as today's performance.
- Disconnect network: status retries, terminal timestamps remain visible and eventually stale. Reconnect resumes available retained messages.
- Stop/reopen, change endpoint/topic, change image, rotate screen and test Android notification/battery restrictions.
