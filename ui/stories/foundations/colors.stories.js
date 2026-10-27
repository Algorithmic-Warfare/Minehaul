import { render, whenAttached, describe } from "../_lib.js";

const PALETTE = [
  ["--mh-ink", "Ink", "Ground in the ink theme, text in paper"],
  ["--mh-ink-soft", "Ink soft", "Raised surface in ink"],
  ["--mh-brand", "Brand", "AWAR oxide: brand fills, your hauls"],
  ["--mh-brand-deep", "Brand deep", "Pressed brand"],
  ["--mh-signal", "Signal", "Accent, focus, lens matches"],
  ["--mh-paper", "Paper", "Ground in paper, text in ink"],
  ["--mh-paper-muted", "Paper muted", "Paper surfaces"],
];

const ROLES = {
  Surfaces: [
    ["--mh-bg", "Page ground"],
    ["--mh-surface", "Cards and plates"],
    ["--mh-surface-2", "Selected rows, raised plates"],
    ["--mh-fg", "Text and icons"],
    ["--mh-muted", "Secondary text"],
    ["--mh-line", "Rules and keylines"],
    ["--mh-trim", "Stronger rules"],
    ["--mh-control-line", "Control outlines"],
  ],
  Action: [
    ["--mh-accent", "Primary action fill"],
    ["--mh-accent-fg", "Text on accent"],
    ["--mh-accent-pressed", "Pressed primary"],
    ["--mh-accent-text", "Accent as text"],
    ["--mh-brand-fill", "Brand fill"],
    ["--mh-brand-fg", "Text on brand"],
    ["--mh-brand-text", "Brand as text"],
  ],
};

const STATES = [
  ["--mh-state-open", "open", "Listed and claimable"],
  ["--mh-state-active", "claimed · collected", "A hauler holds the job"],
  ["--mh-state-window", "delivered", "Dispute window running"],
  ["--mh-state-settled", "settled", "Paid out"],
  ["--mh-state-disputed", "disputed", "Awaiting governance"],
  ["--mh-state-resolved", "resolved", "Governance decided"],
  ["--mh-state-void", "expired · cancelled", "Ended without settling"],
];

const DATA = [
  ["--mh-data-a", "Light job in a stack"],
  ["--mh-data-b", "Dark job in a stack"],
  ["--mh-data-hatch", "Risk-trait hatch lines"],
  ["--mh-data-match", "Meets the lens"],
  ["--mh-data-select", "Selected job"],
  ["--mh-data-rule", "Chart baselines"],
];

const STATUS = [
  ["--mh-ok", "Settled, success toasts"],
  ["--mh-warn", "Leases, deadlines, windows"],
  ["--mh-alert", "Disputes, failures"],
];

// Computed colours arrive as rgb(0–255) or, from color-mix(), as color(srgb 0–1)
function toHex(css) {
  const m = css.match(/-?[\d.]+(?:e-?\d+)?/g);
  if (!m) return css;
  const unit = css.startsWith("color(") ? 255 : 1;
  const [r, g, b, a] = m.map(Number);
  const hex = "#" + [r, g, b].map((v) => Math.min(255, Math.max(0, Math.round(v * unit))).toString(16).padStart(2, "0")).join("");
  return a != null && a < 1 ? `${hex} · ${Math.round(a * 100)}%` : hex;
}

/** Fills every [data-value-of] with the resolved colour of its token, in its own theme scope. */
function resolveValues(root) {
  whenAttached(root, () => {
    for (const out of root.querySelectorAll("[data-value-of]")) {
      const probe = document.createElement("span");
      probe.style.color = `var(${out.dataset.valueOf})`;
      probe.hidden = true;
      out.after(probe);
      out.textContent = toHex(getComputedStyle(probe).color);
      probe.remove();
    }
  });
  return root;
}

const swatch = (token, name, note) => `<div class="sb-swatch">
  <i style="background: var(${token})"></i>
  <span><b>${name}</b><code>${token}</code><small data-value-of="${token}">…</small>${note ? `<small>${note}</small>` : ""}</span>
</div>`;

const SWATCH_CSS = `<style>
  .sb-swatch { display: grid; grid-template-columns: 44px minmax(0, 1fr); gap: 12px; align-items: center; min-width: 0; }
  .sb-swatch i { width: 44px; height: 44px; border: 1px solid var(--mh-line); }
  .sb-swatch b { display: block; font-size: var(--mh-text-sm); }
  .sb-swatch code { display: block; font: var(--mh-text-2xs) / 1.4 var(--mh-font-mono); color: var(--mh-accent-text); }
  .sb-swatch small { display: block; font-size: var(--mh-text-2xs); color: var(--mh-muted); overflow-wrap: anywhere; }
</style>`;

export default {
  title: "Foundations/Colors",
  parameters: describe(
    "Seven palette swatches drive every colour. Roles, lifecycle states and chart colours are derived from them with `var()`, `color-mix()` and `light-dark()`, so changing the palette (or the toolbar's Palette and Theme) restyles everything. Hex values below are resolved live for the current theme.",
  ),
};

export const Palette = {
  render: () =>
    resolveValues(
      render(`${SWATCH_CSS}<div class="sb-stack">
        <div class="sb-grid" style="--sb-min: 230px">${PALETTE.map(([t, n, r]) => swatch(t, n, r)).join("")}</div>
        <div class="sb-section">
          <span class="mh-label">Rebrand: override the palette on :root</span>
          <pre class="sb-code">:root {
  --mh-brand: #3c6e78;   /* mineral teal instead of oxide */
  --mh-signal: #e9ac78;  /* copper accent */
  --mh-cut-scale: 0.5;   /* shallower chamfers */
}</pre>
          <p class="sb-caption">Palette tokens live on <code>:root</code>. Custom properties resolve <code>var()</code> where they are declared, so an override on a nested element only recomputes roles if that element also carries <code>data-mh-theme</code>.</p>
        </div>
      </div>
      <style>.sb-code { margin: 0; padding: 12px 16px; background: var(--mh-surface); border-left: 2px solid var(--mh-accent); font: var(--mh-text-xs) / 1.6 var(--mh-font-mono); overflow-x: auto; }</style>`),
    ),
};

export const Roles = {
  parameters: describe(null, "Roles flip between themes through `light-dark()`. Components only ever read roles, never the palette directly."),
  render: () =>
    resolveValues(
      render(`${SWATCH_CSS}<div class="sb-stack">${Object.entries(ROLES)
        .map(([group, list]) => `<section class="sb-section"><span class="mh-label">${group}</span>
          <div class="sb-grid" style="--sb-min: 230px">${list.map(([t, note]) => swatch(t, t.replace("--mh-", ""), note)).join("")}</div></section>`)
        .join("")}</div>`),
    ),
};

export const LifecycleStates = {
  name: "Lifecycle states",
  parameters: describe(null, "One colour per `ActionStatus` family. Ended states are also hatched wherever they appear, so they never rely on colour alone."),
  render: () =>
    resolveValues(
      render(`${SWATCH_CSS}<div class="sb-stack">
        <div class="sb-grid" style="--sb-min: 240px">${STATES.map(([t, s, note]) => swatch(t, s, note)).join("")}</div>
        <div class="sb-row">${["open", "claimed", "collected", "delivered", "settled", "disputed", "resolved", "expired", "cancelled"]
          .map((s) => `<span class="mh-plate mh-plate--xs mh-status" data-status="${s}">${s}</span>`)
          .join("")}</div>
      </div>`),
    ),
};

export const DataColours = {
  name: "Data colours",
  parameters: describe(null, "Chart colours for stacks, strips and meters. The row of squares shows every state a stack cell can take."),
  render: () =>
    resolveValues(
      render(`${SWATCH_CSS}<div class="sb-stack">
        <div class="sb-grid" style="--sb-min: 230px">${DATA.map(([t, note]) => swatch(t, t.replace("--mh-", ""), note)).join("")}</div>
        <div class="sb-section">
          <span class="mh-label">Stack cells</span>
          <div class="sb-row" style="gap: 20px; align-items: start">
            ${[
              ['data-shade="a"', "Job, light"],
              ['data-shade="b"', "Job, dark"],
              ["data-match", "Match"],
              ['data-shade="a" data-hazard', "Risk trait"],
              ["data-match data-hazard", "Match + risk"],
              ["data-selected", "Selected"],
            ]
              .map(([a, l]) => `<figure style="margin:0; display:grid; gap:6px; justify-items:center"><i class="mh-sq" ${a} style="width:28px"></i><figcaption class="mh-label">${l}</figcaption></figure>`)
              .join("")}
          </div>
        </div>
      </div>`),
    ),
};

export const StatusHues = {
  name: "Status hues",
  parameters: describe(null, "Semantic hues kept apart from the accent. Each is a `light-dark()` pair tuned for contrast on its theme's ground."),
  render: () =>
    resolveValues(
      render(`${SWATCH_CSS}<div class="sb-stack">
        <div class="sb-grid" style="--sb-min: 230px">${STATUS.map(([t, note]) => swatch(t, t.replace("--mh-", ""), note)).join("")}</div>
        <div class="sb-row">
          <span class="mh-plate mh-plate--xs mh-status" data-status="settled">Settled</span>
          <span class="mh-plate mh-plate--xs mh-status" data-status="delivered">Window open</span>
          <span class="mh-plate mh-plate--xs mh-status" data-status="disputed">Disputed</span>
        </div>
      </div>`),
    ),
};

const themeSample = (theme) => `<div data-mh-theme="${theme}" class="sb-stack" style="gap: 16px">
  <span class="mh-label">${theme === "ink" ? "Ink (dark)" : "Paper (light)"}</span>
  <div class="sb-grid" style="--sb-min: 150px">${["--mh-bg", "--mh-surface", "--mh-fg", "--mh-accent", "--mh-accent-text", "--mh-brand-fill", "--mh-ok", "--mh-warn", "--mh-alert"]
    .map((t) => swatch(t, t.replace("--mh-", ""), ""))
    .join("")}</div>
  <div class="sb-row">
    <button type="button" class="mh-plate mh-button mh-button--sm"><span class="mh-button__label">Claim job</span></button>
    <button type="button" class="mh-plate mh-button mh-button--sm mh-button--secondary"><span class="mh-button__label">Manifest</span></button>
    <span class="mh-plate mh-plate--xs mh-status" data-status="open">Open</span>
    <span class="mh-plate mh-plate--xs mh-status" data-status="disputed">Disputed</span>
  </div>
</div>`;

export const BothThemes = {
  name: "Both themes",
  parameters: describe(null, "The same tokens resolved in an ink scope and a paper scope on one page. `data-mh-theme` works on any element."),
  render: () => resolveValues(render(`${SWATCH_CSS}<div class="sb-pair">${themeSample("ink")}${themeSample("paper")}</div>`)),
};
