# OrionBeastFx v7 - buttons and signal cards

- Visible RUN/STOP controls on Home and Trader, separate from LIVE receiver.
- Async native command publishing: no HTTP call on the WebView JavaScript path.
- Real signal cards: BUY/SELL, symbol, timeframe/module, entry, SL, TP, ID, timestamp and lifetime.
- Current EA emits validated structured signals; older plaintext signals are also readable.
- Standalone mt5/OrionBeastFx_Signals.mq5 includes the custom control code inline.
- Connection setup and safety details: EA-INTEGRATION.md.

This is source code, not a compiled APK/EX5. Build Android with the included workflow/Android Studio and compile MT5 in MetaEditor. Start with demo.
