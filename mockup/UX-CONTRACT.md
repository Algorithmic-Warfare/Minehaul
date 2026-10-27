# Minehaul mockup interaction contract

All actions are reversible browser-local demo simulations. No server, signing, payment or wallet integration exists. The repository README and `../docs/adr/0004-transfer-settlement-and-proofs.md` define Transfer lifecycle semantics; `../docs/adr/0005-endpoint-only-transport.md` excludes route attestation. Fixture identities and balances are fictional. Browser storage contains only demo status and a connected boolean.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Select/Listbox | Native HTML select | DESIGN.md | OS-owned popup | Browser filter and sort checks |
| Scrollbar | dist/styles.css global rules | DESIGN.md | Table horizontal overflow | Narrow browser check |
| Toast | app.js notify | This contract | Informational, success, undo | Claim and reset flow |
| Dialog | HTML dialog and shared open/close handlers | This contract | Guide, job details | Escape and focus restoration |
| Search | Shared toolbar and render | This contract | Job board, My hauls | No results and clear |

Navigation, query, network and sort use URL query state. The dataset contains eight jobs; render all matching fixtures, with visible counts. Filter state survives view navigation. Browser-local haul state survives reload where storage is supported. Storage failures fall back to this visit with feedback. All injected HTML comes exclusively from owned fixtures, never raw user input.

Claim: details → connect demo wallet if needed → reserve demo collateral → remain in details, show claimed state, announce result. My hauls is the owning list. Collection and delivery are explicitly simulated. Delivered opens a fictional 24-hour window; the next action explicitly skips demo time and settles. Hauler reward is net of a fixed demo treasury split. Details show the total funded reward and split. Insufficient demo balance blocks claim with an inline explanation. Settlement returns collateral and adds reward once; settled actions only navigate. Demo reset offers Undo.

Native dialog handles focus trapping and inert background; shared code restores focus to the trigger or owning section. All routes use the same button, status, table and notification primitives. English locale and en-US numeric formatting apply. No dates are rendered. No remote data requests need offline/retry/loading states. External fonts may fall back without blocking operation.
