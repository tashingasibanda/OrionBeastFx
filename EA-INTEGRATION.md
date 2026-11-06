# OrionBeastFx — EA/ntfy integration (v5)

The Android app receives EA events and can publish explicit Run/Stop requests. The EA source was not supplied or modified. The app alone cannot control MetaTrader, guarantee that the EA starts stopped, calculate a strategy-specific take-profit, or prove that a trade executed. Test all EA changes on a demo account first.

## Alert and status events (EA → app)
POST UTF-8 JSON as a text/plain body to the configured alert topic, for example `https://ntfy.sh/<alert-topic>`. The app accepts the existing `symbol`, `snapshot`, `summary`, and `heartbeat` events. Structured events are not trading recommendations.

### Dynamic TP display
For a symbol update, the EA may include its **current calculated target price** as `tp`, plus a short `tp_method` description. The app validates that `tp` is a positive finite price and displays the value and method exactly as reported. Each new symbol update replaces the prior row, so the EA should publish a fresh value whenever its calculation changes.

The app does not derive TP from a fixed number, pip distance, ATR, or risk/reward ratio. The calculation formula and inputs must be implemented in the EA and must match your strategy. No TP price is supplied or invented by this project.

Example schema only (placeholders, not trade advice):
```json
{"type":"symbol","symbol":"<broker-symbol>","state":"watch","timeframe":"<timeframe>","tp":"<EA-calculated-price>","tp_method":"<actual method>"}
```

### EA status acknowledgement
After processing a command, publish a status event to the **alert** topic so the app can display the EA-reported state:
```json
{"type":"bot_status","status":"running","command_id":"<received-command-id>"}
```
Use `stopped` when the EA has disabled new entries. This is an EA report over ntfy, not an independently verified broker status.

## Manual control (app → EA)
In app Settings, configure a **separate command topic**, a command token, and confirm that the topic has server-side access restrictions. The app keeps Run/Stop locked until these fields are set. Public ntfy topics are readable/publishable by others; a token typed into the app does not itself make a public topic private. Verify the server’s ACLs and use a protected/self-hosted ntfy setup for any command capable of affecting live trades.

Only a tap on the floating Run or Stop button publishes a command. The request body is a JSON text message to the command topic:
```json
{"type":"bot_command","action":"RUN","command_id":"<unique-id>","sequence":1,"requested_at":<unix-seconds>}
```
`action` is `RUN` or `STOP`; the app sends an Authorization Bearer header using the configured command token. The `sequence` increases on the device. The ntfy HTTP success response means only that ntfy accepted the publish request.

The EA must implement the command listener and its own safety logic. Recommended requirements:
- Initialize the EA with new entries disabled. Do not auto-trade on EA load, app launch, receiver reconnect, or topic reconnect.
- Accept only valid, new commands from the protected topic; check command IDs/sequences and reject stale/replayed or malformed requests.
- RUN may enable new-entry logic only after the EA validates its own risk and market conditions. STOP disables new entries. **STOP does not close existing positions**; keep their normal stop-loss/TP management. Do not close positions unless you explicitly add and test a separate close-all command.
- Publish `bot_status` to the alert topic after applying the command. Include the same `command_id`, and make status reflect the EA’s actual internal enable/disable state.
- Independently enforce lot-size, exposure, spread, margin, stop-loss, and daily-loss limits inside the EA. The phone UI is not a risk engine.

The app does not subscribe to the command topic and cannot know if the EA is listening. It reports the last EA status event and the last request sent; absence of an acknowledgement means status is unknown.

## Existing alerts
The existing signal/summary formats remain in the source. Use real EA values only. Keep alert and command topics separate. Do not publish broker credentials or sensitive account information in ntfy messages.
