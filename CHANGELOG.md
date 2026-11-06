# v8 UI and connection diagnosis correction
- Removed duplicate RUN/STOP panels from Home and Trader. Controls exist only inside the floating bot icon panel.
- Added phone-to-ntfy status, configured topics, LIVE toggle and troubleshooting guidance to the floating panel.
- Retained validated signal cards in Trader and async native RUN/STOP publishing.
- No APK/EX5 compile or end-to-end server/broker test performed here.

# v7 UI correction
- Added directly accessible Home/Trader RUN and STOP buttons.
- Added async native publishing with visible progress/error handling.
- Added validated structured signal events and real signal cards; legacy alerts remain readable.
- Exported standalone .mq5 source separately as requested.
- No APK/EX5 compile or real ntfy/broker test performed here.

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

