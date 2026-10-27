import { render, describe } from "../_lib.js";

const STATUSES = [
  ["open", "Open", "Listed and claimable. Reward is escrowed."],
  ["claimed", "Claimed", "A hauler posted collateral. The haul deadline is running."],
  ["collected", "Collected", "Cargo confirmed collected at the source SSU."],
  ["delivering", "Delivering", "Transient: the delivery handoff commits atomically."],
  ["delivered", "Delivered", "Adapter certified delivery. The dispute window is open."],
  ["settled", "Settled", "Reward split paid; collateral returned."],
  ["disputed", "Disputed", "Opened by a participant or by expiry after claim."],
  ["resolved", "Resolved", "Governance resolved the dispute."],
  ["expired", "Expired", "Unclaimed listing lapsed; reward and cargo refunded."],
  ["cancelled", "Cancelled", "Withdrawn by the lister before a claim."],
];

export default {
  title: "Display/Status & tags",
  parameters: describe(
    "Small labels on chamfered plates. `.mh-status` follows `minehaul_core::action::ActionStatus` through `data-status`; states that end without settling (disputed, expired, cancelled) are hatched so they read without colour. `.mh-tag` names networks and roles, `.mh-lamp` is a 4px status cell, `.mh-count` a numeric chip.",
  ),
  argTypes: {
    status: { control: "select", options: STATUSES.map(([s]) => s), description: "`data-status` value" },
    label: { control: "text" },
  },
  args: { status: "delivered", label: "Delivered" },
  render: ({ status, label }) => render(`<span class="mh-plate mh-plate--xs mh-status" data-status="${status}">${label}</span>`),
};

export const Playground = {};

export const EveryStatus = {
  name: "Every ActionStatus",
  render: () =>
    render(`<table class="mh-table" style="max-width: 760px">
      <thead><tr><th>Chip</th><th>data-status</th><th>Meaning</th></tr></thead>
      <tbody>${STATUSES.map(([s, l, m]) => `<tr><td><span class="mh-plate mh-plate--xs mh-status" data-status="${s}">${l}</span></td><td class="mh-table__id">${s}</td><td style="font-family: var(--mh-font-body)">${m}</td></tr>`).join("")}</tbody>
    </table>`),
};

export const Tags = {
  parameters: describe(null, "Network tags, the brand-filled *Your haul* tag, and live/paused network tags carrying a lamp."),
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-row">
        <span class="mh-plate mh-plate--xs mh-tag" title="Aster Collective">AST</span>
        <span class="mh-plate mh-plate--xs mh-tag" title="Meridian Union">MRD</span>
        <span class="mh-plate mh-plate--xs mh-tag" title="Outer Rim Guild">ORG</span>
        <span class="mh-plate mh-plate--xs mh-tag" style="--mh-plate-fill: var(--mh-brand-fill); --mh-plate-keyline: var(--mh-brand-fill); color: var(--mh-brand-fg)">Your haul</span>
        <span class="mh-plate mh-plate--xs mh-tag">Testnet</span>
      </div>
      <div class="sb-row">
        <span class="mh-plate mh-plate--xs mh-tag"><span class="mh-lamp mh-lamp--sm" data-lit style="--_lamp: var(--mh-ok)"></span>Live</span>
        <span class="mh-plate mh-plate--xs mh-tag"><span class="mh-lamp mh-lamp--sm" data-lit style="--_lamp: var(--mh-warn)"></span>Paused</span>
        <span class="mh-plate mh-plate--xs mh-tag"><span class="mh-lamp mh-lamp--sm"></span>Offline</span>
        <span class="mh-plate mh-plate--xs mh-tag"><span class="mh-lamp mh-lamp--sm" data-lit></span>Leased</span>
      </div>
    </div>`),
};

export const Lamps = {
  parameters: describe(null, "A lamp is dim at rest and lit (with a glow) by `data-lit`, `aria-current` on its parent, or hover/focus on a parent link or button. Override `--_lamp` for other colours."),
  render: () =>
    render(`<div class="sb-row" style="gap: 28px">
      ${[
        ["Dim", ""],
        ["Lit", "data-lit"],
        ["OK", 'data-lit style="--_lamp: var(--mh-ok)"'],
        ["Warn", 'data-lit style="--_lamp: var(--mh-warn)"'],
        ["Alert", 'data-lit style="--_lamp: var(--mh-alert)"'],
        ["Brand", 'data-lit style="--_lamp: var(--mh-brand-fill)"'],
      ]
        .map(([l, a]) => `<span class="sb-row" style="gap: 8px"><span class="mh-lamp" ${a}></span><span class="mh-label">${l}</span></span>`)
        .join("")}
      <a href="#lamp" class="sb-row" style="gap: 8px; color: var(--mh-fg)"><span class="mh-lamp"></span>Hover me</a>
    </div>`),
};

export const Counts = {
  parameters: describe(null, "`.mh-count` for tabs and nav items; `--accent` for things that need attention."),
  render: () =>
    render(`<div class="sb-row">
      <span class="mh-count">11</span>
      <span class="mh-count mh-count--accent">3</span>
      <span class="sb-row" style="gap: 6px; font-size: var(--mh-text-sm)">Open jobs <span class="mh-count">11</span></span>
      <span class="sb-row" style="gap: 6px; font-size: var(--mh-text-sm)">Needs action <span class="mh-count mh-count--accent">2</span></span>
    </div>`),
};
