import { renderStacks } from "../js/stacks.js";
import { renderJobCard, trackHtml, rate, units } from "../js/job.js";
import { JOBS, ENDED, NOW } from "./jobs.js";

const root = document.documentElement;
const int = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });

/* ---------- Palette ---------- */

const KEYS = [
  ["ink", "Ink", "ground in ink theme"],
  ["ink-soft", "Ink soft", "raised surface"],
  ["brand", "Brand", "AWAR oxide"],
  ["brand-deep", "Brand deep", "pressed brand"],
  ["signal", "Signal", "accent, focus, match"],
  ["paper", "Paper", "ground in paper theme"],
  ["paper-muted", "Paper muted", "paper surfaces"],
];

const PRESETS = {
  awar: { ink: "#171716", "ink-soft": "#242321", brand: "#873a3c", "brand-deep": "#63282b", signal: "#ff8d3a", paper: "#f2eee6", "paper-muted": "#d6d0c5" },
  console: { ink: "#101519", "ink-soft": "#1c252c", brand: "#3c6e78", "brand-deep": "#24434a", signal: "#e9ac78", paper: "#e6ecee", "paper-muted": "#9aa8b0" },
  frontier: { ink: "#0b0b0b", "ink-soft": "#171716", brand: "#a1270b", "brand-deep": "#460e04", signal: "#ff4700", paper: "#fafae5", "paper-muted": "#9e9e91" },
};

const palette = { ...PRESETS.awar };
let cutScale = 1;

const swatchHost = document.getElementById("swatch-inputs");
swatchHost.innerHTML = KEYS.map(([key, label, role]) => `<label class="sp-swatch">
    <input type="color" id="pal-${key}" data-key="${key}" value="${palette[key]}">
    <span><b>${label}</b><small data-hex="${key}">${palette[key]}</small><small>${role}</small></span>
  </label>`).join("");

function applyPalette() {
  for (const [key] of KEYS) {
    root.style.setProperty(`--mh-${key}`, palette[key]);
    document.getElementById(`pal-${key}`).value = palette[key];
    swatchHost.querySelector(`[data-hex="${key}"]`).textContent = palette[key];
  }
  root.style.setProperty("--mh-cut-scale", cutScale);
  document.getElementById("css-out").textContent =
    `:root {\n${KEYS.map(([k]) => `  --mh-${k}: ${palette[k]};`).join("\n")}\n  --mh-cut-scale: ${cutScale};\n}`;
  renderRoles();
}

swatchHost.addEventListener("input", (event) => {
  const key = event.target.dataset.key;
  if (!key) return;
  palette[key] = event.target.value;
  document.getElementById("preset").value = "custom";
  applyPalette();
});

document.getElementById("preset").addEventListener("change", (event) => {
  const preset = PRESETS[event.target.value];
  if (preset) Object.assign(palette, preset);
  applyPalette();
});

document.getElementById("cut").addEventListener("input", (event) => {
  cutScale = Number(event.target.value);
  document.getElementById("cut-out").textContent = cutScale.toFixed(2);
  applyPalette();
});

document.getElementById("theme").addEventListener("click", (event) => {
  const button = event.target.closest("[data-theme-set]");
  if (!button) return;
  root.dataset.mhTheme = button.dataset.themeSet;
  for (const b of document.querySelectorAll("[data-theme-set]")) b.setAttribute("aria-pressed", String(b === button));
  renderRoles();
});
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", renderRoles);

document.getElementById("copy-css").addEventListener("click", async (event) => {
  const label = event.currentTarget.querySelector(".mh-button__label");
  const text = document.getElementById("css-out").textContent;
  try {
    await navigator.clipboard.writeText(text);
    label.textContent = "Copied";
  } catch {
    const range = document.createRange();
    range.selectNodeContents(document.getElementById("css-out"));
    getSelection().removeAllRanges();
    getSelection().addRange(range);
    label.textContent = "Selected · press copy";
  }
  setTimeout(() => (label.textContent = "Copy CSS"), 1800);
});

/* Derived roles, resolved through a probe so light-dark() and color-mix() show real values */
const ROLES = [
  ["Surfaces", null],
  ["bg", "--mh-bg"], ["surface", "--mh-surface"], ["surface-2", "--mh-surface-2"], ["fg", "--mh-fg"], ["muted", "--mh-muted"], ["line", "--mh-line"],
  ["Action", null],
  ["accent", "--mh-accent"], ["accent-text", "--mh-accent-text"], ["brand-fill", "--mh-brand-fill"], ["brand-text", "--mh-brand-text"],
  ["Lifecycle", null],
  ["state-open", "--mh-state-open"], ["state-window", "--mh-state-window"], ["state-settled", "--mh-state-settled"], ["state-disputed", "--mh-state-disputed"], ["state-resolved", "--mh-state-resolved"], ["state-void", "--mh-state-void"],
  ["Data", null],
  ["data-a", "--mh-data-a"], ["data-b", "--mh-data-b"], ["data-hatch", "--mh-data-hatch"], ["data-match", "--mh-data-match"], ["data-select", "--mh-data-select"],
];
const probe = document.createElement("span");
probe.hidden = true;
document.body.append(probe);
// Computed colours arrive as rgb(0–255) or, from color-mix(), as color(srgb 0–1)
const toHex = (css) => {
  const m = css.match(/-?[\d.]+(?:e-?\d+)?/g);
  if (!m) return css;
  const unit = css.startsWith("color(") ? 255 : 1;
  const [r, g, b, a] = m.map(Number);
  const hex = "#" + [r, g, b].map((v) => Math.min(255, Math.max(0, Math.round(v * unit))).toString(16).padStart(2, "0")).join("");
  return a != null && a < 1 ? `${hex} · ${Math.round(a * 100)}%` : hex;
};
function renderRoles() {
  document.getElementById("roles").innerHTML = ROLES.map(([name, token]) => {
    if (!token) return `<div class="sp-role-group mh-label">${name}</div>`;
    probe.style.color = `var(${token})`;
    const value = toHex(getComputedStyle(probe).color);
    return `<div class="sp-role"><i style="background: var(${token})"></i><span><b>${token}</b><small>${value}</small></span></div>`;
  }).join("");
}

/* ---------- Data views ---------- */

const live = JOBS;
const all = [...JOBS, ...ENDED];
const card = document.getElementById("job-card");
const views = [];

function show(job) {
  card.innerHTML = renderJobCard(job, { now: NOW });
  for (const v of views) v.select(job.id);
}

views.push(renderStacks(document.getElementById("stacks-board"), {
  title: "Open board · reward rate",
  subtitle: "Every square is 100 units of cargo and every job is one contiguous run, so a band split into many small jobs looks busy instead of thin.",
  items: live.filter((j) => j.status === "open"),
  id: (j) => j.id,
  size: units,
  sizeUnit: "u",
  unit: { per: 100, label: "100 u" },
  metric: rate,
  metricFormat: (v) => v.toFixed(2),
  groups: [
    { key: "bulk", label: "Bulk", code: "< 5 CR/u", range: [0, 5] },
    { key: "standard", label: "Standard", code: "5–12 CR/u", range: [5, 12] },
    { key: "priority", label: "Priority", code: "12–20 CR/u", range: [12, 20] },
    { key: "express", label: "Express", code: "≥ 20 CR/u", range: [20, Infinity] },
  ],
  lens: { value: 12, min: 0, max: 30, step: 0.5, label: "Floor", format: (v) => `${v.toFixed(1)} CR/u` },
  match: (_job, lens, metric) => metric >= lens,
  matchLabel: "Meets your floor",
  hazard: (j) => j.risk ?? null,
  hazardLabel: "Risk trait",
  strip: { domain: [0, 30], ticks: [0, 5, 10, 15, 20, 25, 30], tickFormat: (v) => v.toFixed(0), label: "Where each job sits · true scale (CR per unit) · bar height = cargo units" },
  orderLabels: { metric: "Order · rate", size: "Order · size" },
  selected: "MH-0246",
  onSelect: show,
}));

const STAGE_GROUPS = [
  { key: "open", label: "Open", code: "reward" },
  { key: "claimed", label: "Claimed", code: "reward + collateral" },
  { key: "collected", label: "Collected", code: "reward + collateral" },
  { key: "delivered", label: "Dispute window", code: "until finalized" },
];
const escrowOf = (j) => j.reward + (j.status === "open" ? 0 : j.collateral ?? 0);
views.push(renderStacks(document.getElementById("stacks-escrow"), {
  title: "Escrow held by Minehaul",
  items: live,
  id: (j) => j.id,
  size: escrowOf,
  sizeUnit: "CR",
  sizeFormat: (v) => int.format(v),
  unit: { per: 2000, label: "2,000 CR" },
  perRow: 10,
  metric: rate,
  groups: STAGE_GROUPS,
  groupOf: (j) => j.status,
  match: (j) => j.mine,
  matchLabel: "Your hauls",
  hazard: (j) => j.risk ?? null,
  hazardLabel: "Risk trait",
  orderLabels: { metric: "Order · rate", size: "Order · escrow" },
  selected: "MH-0246",
  onSelect: show,
}));

const rewardsOpen = live.filter((j) => j.status === "open").reduce((s, j) => s + j.reward, 0);
const rewardsLive = live.filter((j) => j.status !== "open").reduce((s, j) => s + j.reward, 0);
const collateral = live.filter((j) => j.status !== "open").reduce((s, j) => s + (j.collateral ?? 0), 0);
const escrowTotal = rewardsOpen + rewardsLive + collateral;
const pct = (v) => `${((v / escrowTotal) * 100).toFixed(1)}%`;
document.getElementById("escrow-split").innerHTML = `<div class="mh-split">
  <span class="mh-label">Escrow composition · ${int.format(escrowTotal)} CR</span>
  <div class="mh-plate mh-plate--xs mh-split__bar" role="img" aria-label="Open rewards ${pct(rewardsOpen)}, claimed rewards ${pct(rewardsLive)}, collateral ${pct(collateral)}">
    <span data-tone="a" style="--share:${rewardsOpen}"></span><span data-tone="accent" style="--share:${rewardsLive}"></span><span data-tone="hatch" style="--share:${collateral}"></span>
  </div>
  <ul class="mh-split__legend">
    <li data-tone="a"><span>Rewards on open listings</span><b class="mh-num">${int.format(rewardsOpen)} CR</b><small>${pct(rewardsOpen)}</small></li>
    <li data-tone="accent"><span>Rewards on live hauls</span><b class="mh-num">${int.format(rewardsLive)} CR</b><small>${pct(rewardsLive)}</small></li>
    <li data-tone="hatch"><span>Hauler collateral</span><b class="mh-num">${int.format(collateral)} CR</b><small>${pct(collateral)}</small></li>
  </ul>
</div>`;

/* Lifecycle gallery */
const gallery = ["MH-0248", "MH-0244", "MH-0246", "MH-0242", "MH-0234", "MH-0233", "MH-0228", "MH-0232", "MH-0231"];
const byId = new Map(all.map((j) => [j.id, j]));
const STATUS_LABEL = { open: "Open", claimed: "Claimed", collected: "Collected", delivered: "Delivered", settled: "Settled", disputed: "Disputed", resolved: "Resolved", expired: "Expired", cancelled: "Cancelled" };
document.getElementById("tracks").innerHTML = gallery.map((id) => {
  const job = byId.get(id);
  return `<div class="sp-track">
    <div class="sp-track__meta"><span class="mh-plate mh-plate--xs mh-status" data-status="${job.status}">${STATUS_LABEL[job.status]}</span><span class="mh-muted">${job.id}</span></div>
    ${trackHtml(job)}
  </div>`;
}).join("");

document.getElementById("statuses").innerHTML = Object.entries(STATUS_LABEL)
  .map(([key, label]) => `<span class="mh-plate mh-plate--xs mh-status" data-status="${key}">${label}</span>`)
  .join("");

/* Busy button demo */
const busy = document.getElementById("busy-demo");
busy.addEventListener("click", () => {
  if (busy.getAttribute("aria-busy")) return;
  busy.setAttribute("aria-busy", "true");
  setTimeout(() => busy.removeAttribute("aria-busy"), 2000);
});

/* Demo buttons inside job cards do nothing; say so */
card.addEventListener("click", (event) => {
  const button = event.target.closest(".mh-button:not(:disabled)");
  if (!button || button.getAttribute("aria-busy")) return;
  button.setAttribute("aria-busy", "true");
  setTimeout(() => button.removeAttribute("aria-busy"), 1200);
});

applyPalette();
show(byId.get("MH-0246"));
