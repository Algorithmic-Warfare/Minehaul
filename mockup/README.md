# Minehaul website mockup

A buildless, browser-local prototype of the hauler experience. All networks, cargo, balances and transfers are fictional demo data. No wallet connection, chain transaction, delivery verification or real payout occurs.

Run `python3 -m http.server 4173 --directory dist` from this folder and visit `http://localhost:4173`.

The job board supports search, network filters, sorting, job details, demo identity, claims and a simulated collection/delivery/settlement lifecycle. Browser storage keeps demo progress; the Demo guide contains a reset action. Search and navigation are URL-backed. The endpoint diagram is schematic and makes no travel-path or distance claim.

Product authority: the repository README and ADRs 0004 and 0005. Transfer is the only supported action; delivery and settlement are separate states. The mockup does not imply production integration.

The mockup predates `../ui` and does not use `@minehaul/ui`. It defines its own colour tokens in `dist/styles.css` and loads Barlow, Barlow Condensed and IBM Plex Mono from Google Fonts at runtime, falling back to Arial and the system monospace offline.

## Verification

`node --check dist/app.js` checks JavaScript syntax. `scripts/verify.cjs` runs browser scenarios with Playwright; use an installed `playwright` package or set `PLAYWRIGHT_MODULE` to its absolute package path. Optionally set `CHROME_EXECUTABLE` to an existing Chromium binary. Screenshots go to `/tmp/minehaul-qa` unless `ARTIFACT_DIR` is set. The test server shuts down after the run.

Verified in Chromium: search/filter/sort, URL restoration, modal Escape and focus restoration, the full demo lifecycle with exact balance assertions, reload persistence, network navigation, reset/undo, empty recovery, storage unavailable, and responsive overflow at 320/390/768px. Desktop screenshot checked at 1440px. JavaScript syntax and DESIGN.md lint passed. This does not constitute a full assistive-technology or cross-browser audit.
