# EA → ntfy → Star Beast FX

The receiver cannot discover your EA's market watch internally. Publish actual EA states to the configured topic. No EA source was provided; this document specifies the new receiver's contract, not your EA's current output.

## Transport
POST to `https://ntfy.sh/OrionBeastFx` (or your configured server/topic).
The HTTP request body is a UTF-8 string containing ONE JSON object below. Use `Content-Type: text/plain; charset=utf-8` so ntfy treats it as a message body, not as the root ntfy JSON publish API. Use an Authorization Bearer header if the server requires a token. MT4/MT5 may require adding your server to allowed WebRequest URLs.

**The following symbols/numbers are documentation/test examples only. They are never preloaded into the app. Substitute your real EA values.**

### Single-symbol update
```json
{"type":"symbol","symbol":"EURUSD","state":"watch","timeframe":"M15","reason":"EA setup criteria met"}
```
Change `state` to `standby` when the EA is waiting. `watch` and `standby` have the meaning assigned by YOUR EA; the receiver does not decide entry conditions. `remove` removes the row from visible groups. `timeframe` and `reason` are optional strings. Exact broker symbol names, including suffixes, are preserved.

### Complete authoritative snapshot
```json
{"type":"snapshot","symbols":[{"symbol":"EURUSD","state":"watch","timeframe":"M15"},{"symbol":"XAUUSD","state":"standby","reason":"Waiting for setup"}]}
```
A snapshot replaces all previous symbols (except newer individual messages during replay). Send `{"type":"snapshot","symbols":[]}` if no symbols are monitored. Publish snapshots periodically, for example after state changes, and on EA startup. Subscribe/start the app before sending its initial snapshot. The app does not send commands back to your EA.

### Daily performance summary
```json
{"type":"summary","date":"2026-11-06","trades":12,"win_rate":67,"net_r":13.95}
```
Use the actual date matching the phone's local calendar day. `win_rate` is a percentage from 0 to 100, NOT a fraction. `trades` must be a nonnegative integer. `net_r` is a finite signed value in R units. These numeric fields are optional: missing values display —, not zero. Summary events replace that date's full summary, not increment it. Your EA calculates results and decides counting policy; the receiver does not manufacture them from signals. Dates use YYYY-MM-DD.

### Heartbeat
```json
{"type":"heartbeat"}
```
Updates the last structured EA message time. It does NOT refresh per-symbol timestamps. Send fresh symbol updates/snapshots for that.

### Regular phone alert
POST a plain message such as your EA's normal signal text. It appears in Signal and triggers Android notifications. Structured symbol/snapshot/summary/heartbeat traffic is kept in History silently to avoid notification floods. Invalid structured messages are kept with an error and do not change terminal state. Unknown JSON event types are rejected, not guessed.

## Ordering and limitations
The receiver uses the ntfy outer message `time` (server seconds) for ordering, not client-supplied timestamps. Older updates do not overwrite newer rows; same-second events are applied in received order. Repeated recent message IDs are ignored (300-message deduplication window). Last saved ID is used for reconnect; retention gaps require a fresh snapshot. A crash around persistence/notification may drop a notification; exactly-once delivery is not guaranteed. Each symbol has one aggregate state per topic, not a separate row per timeframe/EA. Histories and summaries are local device data and no metrics are independently audited.

## Safe testing
Use a PRIVATE temporary test topic to publish example data; do not put sample trades into your live topic. Change Settings to that topic first. No test script auto-publishes anything.
