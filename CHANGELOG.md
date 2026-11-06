# OrionBeastFx v5

- Removed the hero lion icon and added a separate floating Run/Stop control panel.
- Added explicit-only ntfy command publishing, with a separate configured topic/token and access-control acknowledgement.
- Added EA status acknowledgements and dynamic TP fields (`tp`, `tp_method`) to structured symbol events. The app displays EA-calculated TP; it does not calculate TP.
- Added validation tests for TP fields and bot status events.
- EA source was not included; actual EA execution and TP calculation remain to be integrated and tested on demo.

