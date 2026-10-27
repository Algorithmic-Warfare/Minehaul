import { render, describe, icon, identicon, int } from "../_lib.js";
import { JOBS, ENDED, NOW } from "../../demo/jobs.js";
import { NETWORK_DETAIL, CHARACTERS, short } from "../../demo/network.js";
import { rate, units, minCollateral, formatSpan } from "../../js/job.js";

const HOUR = 3_600_000;
const open = JOBS.filter((j) => j.status === "open");
const live = JOBS.filter((j) => j.status !== "open");

export default {
  title: "Display/Data",
  parameters: describe(
    "Building blocks for showing Minehaul figures: stat tiles with a cell sparkline, key–value lists with dotted leaders, copyable ID chips with identicons, live countdowns, and the dense mono table. All numbers use tabular figures with a slashed zero.",
  ),
};

/* ---------- Stat tiles ---------- */

const spark = (values) => {
  const max = Math.max(...values);
  return `<div class="mh-spark" aria-hidden="true">${values.map((v) => `<i style="--v:${(v / max).toFixed(3)}"></i>`).join("")}</div>`;
};

const stat = ({ label, value, unit = "", delta, dir, series }) => `<div class="mh-plate mh-stat">
  <span class="mh-label">${label}</span>
  <b class="mh-stat__value">${value}${unit ? `<small>${unit}</small>` : ""}</b>
  ${delta ? `<span class="mh-stat__delta"${dir ? ` data-dir="${dir}"` : ""}>${delta}</span>` : ""}
  ${series ? spark(series) : ""}
</div>`;

const escrow = open.reduce((s, j) => s + j.reward, 0) + live.reduce((s, j) => s + j.reward + (j.collateral ?? 0), 0);
const avgRate = open.reduce((s, j) => s + rate(j), 0) / open.length;
const disputes = [...JOBS, ...ENDED].filter((j) => j.status === "disputed").length;

export const StatTiles = {
  name: "Stat tiles",
  parameters: describe(
    "`.mh-stat` on a plate: label, value with unit, an optional delta (`data-dir=\"up|down\"`) and an optional `.mh-spark` of stacked cells, where the last bar takes the accent. Values here are computed from the demo jobs; the 12-day series are illustrative.",
  ),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 210px">
      ${stat({ label: "Escrow held", value: int.format(escrow), unit: "CR", delta: "+12.4% · 24h", dir: "up", series: [140, 152, 149, 171, 168, 180, 199, 205, 214, 226, 231, Math.round(escrow / 1000)] })}
      ${stat({ label: "Open jobs", value: open.length, delta: "+3 since yesterday", dir: "up", series: [6, 7, 5, 8, 9, 9, 7, 8, 10, 9, 8, open.length] })}
      ${stat({ label: "Avg reward rate", value: avgRate.toFixed(2), unit: "CR/u", delta: "−0.8 · 7d", dir: "down", series: [15, 14, 16, 15, 13, 14, 13, 12, 13, 12, 12, avgRate] })}
      ${stat({ label: "Disputes open", value: disputes, delta: "Awaiting governance", series: [0, 0, 1, 1, 0, 0, 0, 1, 2, 1, 1, disputes] })}
    </div>`),
};

/* ---------- Key–value ---------- */

const mrd = NETWORK_DETAIL.find((n) => n.tag === "MRD");

export const KeyValue = {
  name: "Key–value",
  parameters: describe(null, "`<dl class=\"mh-kv\">` with dotted leaders, for configuration and receipts. This is Meridian Union's `NetworkConfig`, fixed into every listing at creation."),
  render: () =>
    render(`<dl class="mh-kv" style="max-width: 460px">
      <div><dt>Network</dt><dd>${mrd.name} · ${mrd.tag}</dd></div>
      <div><dt>Reward asset</dt><dd>${mrd.config.rewardAsset}</dd></div>
      <div><dt>Min collateral ratio</dt><dd>${(mrd.config.minCollateralRatioBps / 100).toFixed(2)}% (${mrd.config.minCollateralRatioBps} bps)</dd></div>
      <div><dt>Max cargo lines</dt><dd>${mrd.config.maxCargoLines}</dd></div>
      <div><dt>Dispute window</dt><dd>${formatSpan(mrd.config.disputeWindowMs)}</dd></div>
      <div><dt>Open marketplace</dt><dd>${mrd.config.openMarketplace ? "Yes" : "No · members only"}</dd></div>
      <div><dt>Treasury</dt><dd>${short(mrd.treasury)}</dd></div>
    </dl>`),
};

/* ---------- ID chip ---------- */

const chip = ({ label, value, withIcon, copyLabel }) => `<span class="mh-id">
  ${withIcon ? identicon(value, { size: 20 }) : ""}${label ? `<span class="mh-id__label">${label}</span>` : ""}
  <code title="${value}">${short(value, 8, 6)}</code>
  <button type="button" class="mh-id__copy" data-mh-copy="${value}" aria-label="${copyLabel}">${icon("copy")}</button>
</span>`;

export const IdChip = {
  name: "ID chip",
  parameters: describe(
    null,
    "Object ids, addresses and transaction digests, truncated in the middle with the full value in `title`. The copy button uses `data-mh-copy`; js/behaviors.js swaps in a check for a moment and fires `mh:copied`. Identicons come from `identicon(address)` and follow the palette.",
  ),
  render: () =>
    render(`<div class="sb-stack" style="justify-items: start">
      ${chip({ label: "Job", value: "0x6a1f93c2e7b04d58a9c3f1e2d7b6a5c4e8f0d1b9", copyLabel: "Copy job object ID" })}
      ${chip({ label: "Treasury", value: mrd.treasury, withIcon: true, copyLabel: "Copy treasury address" })}
      ${chip({ value: CHARACTERS.vex.address, withIcon: true, copyLabel: `Copy ${CHARACTERS.vex.name}'s address` })}
      ${chip({ label: "Tx", value: "8e1f7c03b2a94d6e5f18c7a0b3d92e4f6a1c8b5d7e0f3a2c9b4d6e8f1a0c42ab", copyLabel: "Copy transaction digest" })}
      <div class="sb-row">${Object.values(CHARACTERS).map((c) => `<span class="sb-row" style="gap: 8px; font-size: var(--mh-text-sm)">${identicon(c.address, { size: 28, label: `${c.name} identicon` })}${c.name}</span>`).join("")}</div>
    </div>`),
};

/* ---------- Countdown ---------- */

const byId = (id) => JOBS.find((j) => j.id === id);
const countdown = ({ label, end, note, warn = 0, alert = 0, sm }) => `<div class="sb-section" style="gap: 6px">
  <span class="mh-label">${label}</span>
  <span class="mh-countdown${sm ? " mh-countdown--sm" : ""}" role="timer" data-mh-countdown="${end}" data-now="${NOW}"${warn ? ` data-warn-under="${warn}"` : ""}${alert ? ` data-alert-under="${alert}"` : ""}></span>
  <span class="sb-caption">${note}</span>
</div>`;

export const Countdown = {
  parameters: describe(
    null,
    "`data-mh-countdown` takes an end time (ms or ISO) and keeps the text current every second. `data-warn-under` and `data-alert-under` (ms) switch the tone as time runs low; `data-ended` is set at zero. These read from the demo clock via `data-now`, so they tick from the same moment the rest of the stories show.",
  ),
  render: () => {
    const j46 = byId("MH-0246");
    const j36 = byId("MH-0236");
    const j42 = byId("MH-0242");
    return render(`<div class="sb-grid" style="--sb-min: 240px">
      ${countdown({ label: "Haul deadline · MH-0246", end: j46.claimedAt + j46.haulDurationMs, note: "Expiry after claim opens a dispute.", warn: 3 * HOUR, alert: 2 * HOUR })}
      ${countdown({ label: "Haul deadline · MH-0236", end: j36.claimedAt + j36.haulDurationMs, note: "Under 2h: alert tone.", warn: 3 * HOUR, alert: 2 * HOUR })}
      ${countdown({ label: "Dispute window · MH-0242", end: j42.deliveredAt + j42.disputeWindowMs, note: "Anyone can finalize when it ends.", warn: 2 * HOUR })}
      ${countdown({ label: "Listing · MH-0240", end: byId("MH-0240").listingExpiresAt, note: "Unclaimed listings refund the lister.", alert: HOUR, sm: true })}
      ${countdown({ label: "Ended", end: NOW - HOUR, note: "data-ended dims it.", sm: true })}
    </div>`);
  },
};

/* ---------- Table ---------- */

export const Table = {
  parameters: describe(
    null,
    "`.mh-table` inside `.mh-table-scroll`: dense mono rows, `__num` cells right-aligned, `__id` muted, `aria-selected` for the selected row, and a totals footer. This is the open board as a list.",
  ),
  argTypes: { selected: { control: "select", options: open.map((j) => j.id) } },
  args: { selected: "MH-0230" },
  render: ({ selected }) => {
    const rows = [...open].sort((a, b) => rate(b) - rate(a));
    const totalUnits = rows.reduce((s, j) => s + units(j), 0);
    const totalReward = rows.reduce((s, j) => s + j.reward, 0);
    return render(`<div class="mh-table-scroll"><table class="mh-table">
      <caption class="mh-sr">Open Transfer jobs, highest reward rate first</caption>
      <thead><tr><th>Job</th><th>Route</th><th>Cargo</th><th class="mh-table__num">Units</th><th class="mh-table__num">Reward</th><th class="mh-table__num">Rate</th><th class="mh-table__num">Min collateral</th><th>Status</th></tr></thead>
      <tbody>${rows
        .map(
          (j) => `<tr${j.id === selected ? ' aria-selected="true"' : ""}>
          <td>${j.id} <span class="mh-plate mh-plate--xs mh-tag" title="${j.network.name}">${j.network.tag}</span></td>
          <td class="mh-table__id">${j.source.ssu} → ${j.destination.ssu}</td>
          <td style="font-family: var(--mh-font-body)">${j.manifest[0].label}${j.manifest.length > 1 ? ` +${j.manifest.length - 1}` : ""}${j.risk ? ` <span title="${j.risk}" style="color: var(--mh-warn)">${icon("warning", { label: j.risk })}</span>` : ""}</td>
          <td class="mh-table__num">${int.format(units(j))}</td>
          <td class="mh-table__num">${int.format(j.reward)}</td>
          <td class="mh-table__num">${rate(j).toFixed(2)}</td>
          <td class="mh-table__num">${int.format(minCollateral(j))}</td>
          <td><span class="mh-plate mh-plate--xs mh-status" data-status="open">Open</span></td>
        </tr>`,
        )
        .join("")}</tbody>
      <tfoot><tr><td colspan="3">${rows.length} jobs</td><td class="mh-table__num">${int.format(totalUnits)}</td><td class="mh-table__num">${int.format(totalReward)}</td><td class="mh-table__num">${(totalReward / totalUnits).toFixed(2)}</td><td colspan="2"></td></tr></tfoot>
    </table></div>`);
  },
};
