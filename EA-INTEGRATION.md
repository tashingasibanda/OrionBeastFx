# OrionBeastFx v8: floating EA controls and signal cards

## What was wrong
Android v5 publishes authenticated JSON bot_command messages with action RUN/STOP. The old EA accepts only plaintext RUN prefixes, reads without authentication, lacks STOP and publishes no bot_status acknowledgement. A successful HTTP publish was not proof of an order.

## Behaviour — read before turning trading on
- The EA starts STOPPED on every load/restart. Scanning may continue while stopped.
- **Default, AutoTradeWhileRunning=false:** each app RUN attempts the latest unexpired pending signal once. RUN with no pending signal does not place an order. Another signal requires another RUN. The app shows EA READY · manual RUN, not continuous trading.
- **Optional, AutoTradeWhileRunning=true:** a valid RUN discards old pending signals and arms subsequent fresh signals until STOP. Each fresh signal may open an order, subject to the existing EA checks. This is a deliberate strategy-execution change, not the default.
- STOP disables new entries and clears the pending queue. It does NOT close or cancel broker orders already submitted and does NOT disable MT5 globally. Existing broker SL/TP remain in place; the supplied EA does not implement trailing-stop management.
- A new valid RUN can re-enable entries after STOP. Plaintext RUN, RUN ALL, RUN <id> and RUN <symbol> are disabled; the Android buttons send exact JSON RUN or STOP.
- The original trend/spike signal logic and dynamic SL/TP formulas are unchanged. This is a connection repair, NOT an audit of strategy profitability, volume rounding, risk sizing, margin or netting-account behaviour.

## 1. Protect ntfy first
Use an HTTPS ntfy server that supports tokens and server-side topic ACLs. Pick two distinct topic names using only letters, digits, underscores or hyphens:
- Alert/status topic: MT5 may publish; the app may subscribe. Do not allow untrusted publishers to spoof status.
- Command topic: only authorised app clients may publish; MT5 may subscribe. Deny anonymous access, especially publishing.

An unpredictable topic name, an app checkbox or a token alone does NOT make a public topic private. Enforce ACLs on the server. Do not post tokens or broker credentials in topic messages or screenshots. The Android app stores tokens in its private preferences; secure the phone and MT5 host. Use separate least-privilege tokens where the server allows it. No credentials are bundled.

## 2. Install/compile in MT5 on Windows PC or VPS
1. Open MT5 → File → Open Data Folder → MQL5 → Experts. Create an OrionBeastFx folder.
2. Copy mt5/OrionBeastFx_Signals.mq5 into that folder. It is standalone: custom control code is bundled inline. The archived .mqh is supplied for reference only.
3. Open the .mq5 in MetaEditor and compile. MT5’s standard Trade/Trade.mqh is still required (normally installed with MT5).
4. MT5 → Tools → Options → Expert Advisors → enable Allow WebRequest for the exact HTTPS ntfy server origin you use.
5. Attach the EA to ONE chart, not one chart per symbol. It scans the configured symbols itself.
6. Set inputs:

| MT5 input | Value |
|---|---|
| NtfyServer | Same HTTPS server URL as Android |
| NtfyTopic | Alert/status topic (same as Android Topic) |
| CommandTopic | Separate protected command topic (same as Android Command topic) |
| CommandReadToken | Token permitted to read the command topic |
| AlertWriteToken | Token permitted to publish to the alert topic |
| ConfirmProtectedTopics | true ONLY after server ACLs are verified |
| TradeOnRun | true to permit orders; false remains signal-only and rejects RUN |
| AutoTradeWhileRunning | false by default; true ONLY if you want continuous fresh-signal entries after RUN |
| CommandPollSeconds | 2 by default |
| CommandMaxAgeSeconds | 60 by default |
| StatusEverySeconds | 30 by default |

7. Enable Algo Trading and the EA's trading permission only on a DEMO account for testing. Review symbol names, lot/risk inputs, MaxOpenTrades and all broker constraints.

**MT5 mobile does not host EAs.** MT5 and the EA must stay running on the PC/VPS. Use one PC/VPS receiver for this account/command channel: a terminal-local lock cannot coordinate different computers. If a crashed EA leaves a receiver lock, remove other instances and restart the terminal. Broker execution still depends on market conditions and trading permissions.

## 3. Build and configure Android
This archive contains the Android Studio source project, not a precompiled APK.
- Open OrionBeastFx in Android Studio with JDK 17 and Android SDK 35, sync Gradle, then build a debug APK; or
- Put the project files at a GitHub repository root and run the included Build OrionBeastFx APK workflow. It installs Gradle 8.9, runs unit tests and assembles app-debug.apk. Publishing/uploading to GitHub is your action, not performed here.

In the installed app's Settings, set server, alert Topic and alert-read Token. Set Command topic, command-publish Token and access-control acknowledgement. Save. Turn LIVE on and grant notification permission so the app can receive status acknowledgements. The token used on the phone need not be the same token as the EA if permissions differ.

## 4. Demo acceptance checklist
1. Load EA: app should receive STOPPED within about one heartbeat after LIVE connects. Starting the EA or phone must not place a trade.
2. Manual mode: wait for a fresh signal, tap RUN once, then inspect app messages AND MT5 Trade/History and Experts logs. An acknowledgement confirms the EA processed a command; it is not independent broker proof of a fill.
3. Tap STOP: app should show matching STOPPED. Verify new entries are blocked. Existing positions must not be closed by STOP.
4. Repeat a command ID through a controlled test client: it must not submit a second order. Old/future/malformed and plaintext messages must be rejected. Keep phone and PC UTC clocks synchronised.
5. Disable Algo Trading: RUN should be rejected with a status note. Disable TradeOnRun: RUN should likewise be rejected; STOP/status polling must still work.
6. Disconnect the EA/receiver: app must eventually show stale/unconfirmed, never treat an unrelated or same-second old acknowledgement as success.
7. If you deliberately enable continuous mode, RUN must ignore pre-RUN queued signals and only allow future fresh signals. STOP ends that session. Repeat on demo before considering live use.

## Operational limits
- Network polling and MT5 WebRequest are synchronous. STOP cannot interrupt an order already being sent or an in-progress scan/request; network failures can prevent delivery entirely. Use MT5/broker controls directly for emergencies. There is no close-all command or offline kill switch.
- Durable command-ID markers are flushed before any order attempt. After a crash, the design prefers missing a command over submitting the same ID twice; a publish is not an exactly-once execution guarantee. Markers use terminal global variables and their usual retention rules.
- The updated app supplies a persistent controller UUID and reserves an increasing sequence before publishing. The EA persists a sequence watermark per controller and rejects older/equal sequences, including a delayed RUN after a newer STOP in the same second. Use ONE controlling phone per topic; sequence numbers do not order unrelated phones. Clearing app data creates a new controller identity. Legacy v5 clients without controller_id are rejected: rebuild/install this matching updated app.
- Poll/heartbeat intervals use a monotonic clock; command expiry still requires correct UTC on the phone, server and PC. Do not send commands with incorrect clocks.
- The app correlates status to the last requested command ID and marks old reports stale. A valid later external controller's report may leave this phone's request unconfirmed; that is intentional.
- Protected topics are essential: authentication is enforced by ntfy ACLs, not by cryptographic signatures inside the EA payload.
- Strategy Tester does not exercise this live WebRequest connection. Use a running demo terminal.

## Verification status
The supplied source was mechanically integrated, strategy-math sections checked unchanged, and archive integrity checked. A test report in the ZIP records the host-side checks actually performed. No MetaEditor, Android SDK/JDK/Gradle, broker terminal or private ntfy credentials were available in the execution environment. Neither .ex5 nor .apk is supplied or claimed tested. Compile both projects, run the demo checklist and send any real compiler diagnostics back for correction.

## v7 buttons and cards
RUN and STOP are directly visible on Home and Trader. They unlock only after command settings are valid. Publishing runs on a native background queue; the UI shows sending, publish outcome, then the matching EA acknowledgement. No command is sent merely by opening the app. LIVE is still an independent receiver toggle. If the receiver is off the app warns you; it does not pretend to know that the EA acted.

Trader shows cards for real trend/spike signals with BUY/SELL, symbol/timeframe, entry/SL/TP, timestamp and signal ID. EXPIRED is based on the signal's advertised lifetime, not proof of broker execution or whether a pending signal was consumed. There is intentionally no misleading per-card trade button: default RUN still attempts the EA's latest pending signal, not an arbitrarily selected card. Original alert details are retained inside each card. Structured status/heartbeat/order reports are not rendered as signal cards; History retains raw received messages.

The separate downloadable OrionBeastFx_Signals_v7.mq5 has exactly the same bytes as mt5/OrionBeastFx_Signals.mq5 inside this ZIP. You do not need an extra custom .mqh to use it. Rebuild/install the matching v7 app; older APKs do not have the async bridge or card reducer.


## Floating bot icon diagnosis (v8)
Tap the round floating bot icon at the lower-right to see the phone receiver state, EA-reported state, server/topic names (not tokens), RUN/STOP, a phone LIVE toggle, and a settings shortcut. No direct phone-to-MT5 socket is used: both endpoints reach the same protected ntfy server. If no EA status arrives, the panel lists the required MT5 PC/VPS, WebRequest, topic and token checks.
