# OrionBeastFx v6 connection repair

Read EA-INTEGRATION.md before use. MT5 source is in mt5/.

# OrionBeastFx v5 — manual EA controls and dynamic TP display

**This archive is Android source code, not an installable APK.** Build it with the included GitHub Actions workflow, then install the APK from the successful build artifact. Android compilation and phone delivery still need to be verified in your build/device environment. Android 8.0+ is required.

## v5 changes
- Removed the hero banner lion image; added a floating bot icon above the pinned bottom navigation. Tapping it opens a compact Run/Stop panel.
- Run and Stop are never sent automatically. The app publishes one explicit command only after a button tap, using a separate configured command topic and token.
- The app shows “requested” until an EA `bot_status` message is received. ntfy accepting a request does not prove the EA received it or placed an order.
- Symbols can display `tp` and `tp_method` exactly as sent by the EA. The app does not calculate or hardcode TP prices; dynamic calculation remains EA-side.
- STOP is specified as “disable new entries”; it does not close existing positions. Existing open positions remain under the EA’s normal management.

## Required EA-side integration
The EA source was not included, so this project does **not** change the EA, guarantee that it starts in a stopped state, or place trades. Follow `EA-INTEGRATION.md` and update the EA to initialize with trading disabled, listen to the protected command topic, implement the TP calculation, and publish status acknowledgements before relying on the controls. Upload your `.mq4` or `.mq5` file for the EA-side change.

## Security and risk
Public ntfy topics are not suitable for trade controls: other publishers may forge commands or status messages. Use a separate topic with server-side access control and a token, and verify those permissions on your server. The app’s confirmation checkbox is not a security mechanism. Do not use live trading until you have tested the command and TP behavior on a demo account.

The app does not submit broker orders itself. It only publishes a control request after a tap; the EA is responsible for all execution and risk controls.

## Build and install
1. Extract the ZIP and upload the contents of `OrionBeastFx/` (including `.github/`) to your repository root.
2. Open **Actions → Build OrionBeastFx APK → Run workflow**.
3. After a successful workflow, download `OrionBeastFx-debug-APK`, extract it, and install `app-debug.apk`—not this source ZIP.
4. Allow installation from your browser/file manager if Android asks. Keep any previous app installed; debug signing-key changes may prevent in-place updates.

See `EA-INTEGRATION.md` for message formats and limitations.
