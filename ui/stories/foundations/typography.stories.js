import { render, describe, int } from "../_lib.js";

const SCALE = [
  ["--mh-text-3xl", "3rem", "Minehaul", "display"],
  ["--mh-text-2xl", "2.25rem", "253,630 CR", "mono"],
  ["--mh-text-xl", "1.5rem", "Structural alloy · 1,600 u", "display"],
  ["--mh-text-lg", "1.125rem", "SSU-04 Meridian Outpost", "mono"],
  ["--mh-text-md", "0.9375rem", "Collect at the source, then deliver to the destination SSU.", "mono"],
  ["--mh-text-sm", "0.8125rem", "Collateral is measured against the reward, rounded up.", "mono"],
  ["--mh-text-xs", "0.75rem", "Expiry after claim opens a dispute.", "mono"],
  ["--mh-text-2xs", "0.6875rem", "DISPUTE WINDOW · 24H", "label"],
];

const AMOUNTS = [19000, 11400, 8550, 23750, 6650, 100000, 2025, 130];

export default {
  title: "Foundations/Typography",
  parameters: describe(
    "Two faces, after AWAR: **Space Grotesk** for display and **JetBrains Mono** for everything else, including body copy. Fonts are not bundled; set `--mh-font-display` and `--mh-font-mono` to use others.",
  ),
};

export const Faces = {
  render: () =>
    render(`<div class="sb-split">
      <section class="sb-section">
        <span class="mh-label">Display · --mh-font-display</span>
        <p class="mh-display" style="margin:0; font-size: var(--mh-text-3xl)">Haul what the frontier needs</p>
        <p class="sb-caption">Space Grotesk 700, tight tracking, balanced wrap. Page titles, section heads, job titles and stack column names.</p>
      </section>
      <section class="sb-section">
        <span class="mh-label">Mono · --mh-font-mono</span>
        <p style="margin:0; font: 500 var(--mh-text-xl) / 1.3 var(--mh-font-mono)">MH-0246 · 23,750 CR · 0x7a3e…c1f0</p>
        <p class="sb-caption">JetBrains Mono for body copy, labels, figures, IDs and controls. It is also the body face (<code>--mh-font-body</code>).</p>
      </section>
    </div>`),
};

export const Scale = {
  parameters: describe(null, "The text scale tokens with the role each step usually plays."),
  render: () =>
    render(`<div class="sb-stack" style="gap: 14px">${SCALE.map(
      ([token, size, text, kind]) => `<div style="display:grid; grid-template-columns: minmax(130px, 11rem) minmax(0, 1fr); gap: 16px; align-items: baseline; border-bottom: 1px solid var(--mh-line); padding-bottom: 12px">
        <span><code style="font: var(--mh-text-2xs) / 1.4 var(--mh-font-mono); color: var(--mh-accent-text)">${token}</code><br><span class="mh-muted" style="font-size: var(--mh-text-2xs)">${size}</span></span>
        <span class="${kind === "display" ? "mh-display" : kind === "label" ? "mh-label" : ""}" style="font-size: var(${token}); min-width: 0; overflow-wrap: anywhere">${text}</span>
      </div>`,
    ).join("")}</div>`),
};

export const LabelsAndNumbers = {
  name: "Labels and numbers",
  parameters: describe(null, "`.mh-label` is the tracked uppercase utility label. `.mh-num` sets tabular figures with a slashed zero so amounts line up and 0 never reads as O."),
  render: () =>
    render(`<div class="sb-split">
      <section class="sb-section">
        <span class="mh-label">.mh-label</span>
        <div class="sb-stack" style="gap: 10px">
          <span class="mh-label">Reward split · fixed at listing</span>
          <span class="mh-label">Haul deadline</span>
          <span class="mh-label">Where each job sits · true scale</span>
        </div>
      </section>
      <section class="sb-section">
        <span class="mh-label">.mh-num · right-aligned</span>
        <div class="mh-num" style="display:grid; justify-items:end; gap: 4px; font-size: var(--mh-text-lg); max-width: 220px">
          ${AMOUNTS.map((a) => `<span>${int.format(a)} <small class="mh-muted" style="font-size: var(--mh-text-xs)">CR</small></span>`).join("")}
        </div>
      </section>
    </div>`),
};

export const Usage = {
  parameters: describe(null, "How the faces combine on a typical Minehaul surface."),
  render: () =>
    render(`<article class="mh-plate mh-plate--lg" style="padding: var(--mh-space-5); display:grid; gap: 10px; max-width: 640px">
      <span class="mh-label">Transfer · MH-0248</span>
      <h3 class="mh-display" style="margin:0; font-size: var(--mh-text-xl)">Refined ore · 2,400 u</h3>
      <p style="margin:0; font-size: var(--mh-text-sm)">From <b>SSU-01</b> Aster Prime to <b>SSU-04</b> Meridian Outpost. The protocol does not prescribe or attest the travel path.</p>
      <div class="sb-row" style="gap: 24px">
        <span><span class="mh-label">Reward</span><br><b class="mh-num" style="font-size: var(--mh-text-xl)">19,000</b> <small class="mh-muted">CR</small></span>
        <span><span class="mh-label">Min collateral</span><br><b class="mh-num" style="font-size: var(--mh-text-xl)">9,500</b> <small class="mh-muted">CR</small></span>
      </div>
      <ul class="sb-caption" style="padding-left: 1.1em; margin: 6px 0 0">
        <li>Display face for the one line that names the thing; never for body text or figures.</li>
        <li>Sentence case for headings, uppercase only for <code>.mh-label</code> and buttons.</li>
        <li>Keep running text near 65 characters per line.</li>
      </ul>
    </article>`),
};
