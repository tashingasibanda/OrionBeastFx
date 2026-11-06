# v6 connection repair
- Matched Android JSON protocol to MT5; authenticated command reads and status writes.
- Explicit STOP, startup-stopped gate, UTC TTL, durable duplicate-command suppression.
- One channel receiver per MT5 terminal/account; matching command IDs and stale/unconfirmed UI.
- Original manual latest-pending RUN is the default; optional continuous mode requires explicit EA input.
- Preserved indicator calculations and dynamic TP/SL; no new profit or risk guarantees.
- Source-level protocol checks and host-side UI tests only; no Android/MetaEditor compilation or live broker test here.

# OrionBeastFx v5

- Removed the hero lion icon and added a separate floating Run/Stop control panel.
- Added explicit-only ntfy command publishing, with a separate configured topic/token and access-control acknowledgement.
- Added EA status acknowledgements and dynamic TP fields (`tp`, `tp_method`) to structured symbol events. The app displays EA-calculated TP; it does not calculate TP.
- Added validation tests for TP fields and bot status events.
- EA source was not included; actual EA execution and TP calculation remain to be integrated and tested on demo.

