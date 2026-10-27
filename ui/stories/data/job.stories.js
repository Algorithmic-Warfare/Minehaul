import { render, describe, int } from "../_lib.js";
import { renderJobCard, trackHtml, meterHtml, formatTime } from "../../js/job.js";
import { JOBS, ENDED, NOW } from "../../demo/jobs.js";

const ALL = [...JOBS, ...ENDED];
const byId = (id) => ALL.find((j) => j.id === id);
const HOUR = 3_600_000;

const card = (id) => render(`<div style="max-width: 940px">${renderJobCard(byId(id), { now: NOW })}</div>`);

export default {
  title: "Data/Job card",
  parameters: describe(
    "`renderJobCard(job, { now })` from js/job.js renders one Transfer from a record shaped like `minehaul_core::action::HaulAction`: endpoints with no travel-path claim, reward and the collateral minimum (rounded up, never zero), the lifecycle track, the timing that applies to the current state, the payout split fixed at listing, the manifest, and actions that fit the status. It returns an HTML string of library classes, so a server or framework can emit the same markup.",
  ),
  argTypes: {
    job: { control: "select", options: ALL.map((j) => j.id), description: "Any demo job, open, live or ended" },
  },
  args: { job: "MH-0246" },
  render: ({ job }) => card(job),
};

export const Playground = {};
export const Open = { args: { job: "MH-0248" }, parameters: describe(null, "Claimable. The listing-expiry meter runs and the primary action posts the minimum collateral.") };
export const Claimed = { args: { job: "MH-0244" }, parameters: describe(null, "Collateral posted; the haul deadline is running. Collection evidence stays outside the protocol.") };
export const Collected = { args: { job: "MH-0246" }, parameters: describe(null, "Cargo collected at the source. Delivery needs an adapter to certify the handoff to the destination SSU.") };
export const Delivered = { name: "Delivered (dispute window)", args: { job: "MH-0242" }, parameters: describe(null, "Reward and collateral stay escrowed while the dispute window runs. Finalize unlocks when it ends, for anyone.") };
export const Settled = { args: { job: "MH-0234" }, parameters: describe(null, "Paid to the fixed hauler and treasury addresses. The track closes in the settled colour.") };
export const Disputed = { args: { job: "MH-0233" }, parameters: describe(null, "The track leaves through a hatched exit after the last stage reached.") };
export const Expired = { args: { job: "MH-0232" }, parameters: describe(null, "An unclaimed listing that lapsed. Reward and cargo were refunded to the lister.") };

export const Track = {
  argTypes: { job: { table: { disable: true } } },
  parameters: describe(
    null,
    "`.mh-track`: interlocking plates following `ActionStatus`. Done steps fill, the current one lights its lamp in the accent, and exits (disputed, resolved, expired, cancelled) attach as a hatched final step that reads without colour. `trackHtml(job)` builds it. Delivering is skipped because the delivery handoff commits atomically. The track scrolls sideways on narrow screens.",
  ),
  render: () => {
    const ids = ["MH-0248", "MH-0244", "MH-0246", "MH-0242", "MH-0234", "MH-0233", "MH-0228", "MH-0232", "MH-0231"];
    return render(`<div class="sb-stack">${ids
      .map((id) => {
        const j = byId(id);
        return `<div class="sb-section" style="gap: 8px"><span class="sb-row" style="gap: 8px"><span class="mh-plate mh-plate--xs mh-status" data-status="${j.status}">${j.status}</span><span class="mh-label">${j.id}</span></span>${trackHtml(j)}</div>`;
      })
      .join("")}</div>`);
  },
};

export const Meter = {
  parameters: describe(
    null,
    "`.mh-meter`: time or quantity as a ladder of square cells, so a window reads as countable hours. Set `--mh-meter-value` (0–1) and `--mh-meter-cells`; the fill snaps to whole cells where CSS `round()` is supported. Tones: `deadline` (accent), `window` (warn), `settled` (ok), `alert`. `meterHtml()` in js/job.js switches a deadline to alert in its last quarter.",
  ),
  argTypes: {
    job: { table: { disable: true } },
    value: { control: { type: "range", min: 0, max: 1, step: 0.01 } },
    cells: { control: { type: "range", min: 4, max: 48, step: 1 } },
    tone: { control: "inline-radio", options: ["deadline", "window", "settled", "alert"] },
    label: { control: "text" },
  },
  args: { value: 0.42, cells: 24, tone: "window", label: "Dispute window" },
  render: ({ value, cells, tone, label }) => {
    const left = Math.round((1 - value) * cells * 60);
    const ex = byId("MH-0246");
    return render(`<div class="sb-stack" style="max-width: 640px">
      <div class="mh-meter" data-tone="${tone}" style="--mh-meter-value:${value}; --mh-meter-cells:${cells}" role="meter" aria-label="${label}" aria-valuemin="0" aria-valuemax="${cells}" aria-valuenow="${(value * cells).toFixed(1)}">
        <div class="mh-meter__head"><span class="mh-label">${label}</span><span class="mh-num">${Math.floor(left / 60)}h ${String(left % 60).padStart(2, "0")}m left</span></div>
        <div class="mh-meter__bar"></div>
        <div class="mh-meter__foot"><span>${Math.round(value * cells)} of ${cells} cells</span><span>tone: ${tone}</span></div>
      </div>
      <div class="mh-rule">From js/job.js</div>
      ${meterHtml({ label: "Haul deadline · MH-0246", start: ex.claimedAt, end: ex.claimedAt + ex.haulDurationMs, now: NOW, tone: "deadline", foot: [`Claimed ${formatTime(ex.claimedAt)}`, "Expiry opens a dispute"] })}
      ${meterHtml({ label: "Haul deadline · MH-0236 (last quarter)", start: byId("MH-0236").claimedAt, end: byId("MH-0236").claimedAt + 10 * HOUR, now: NOW, tone: "deadline", foot: ["Under 25% left switches to alert"] })}
      <div class="mh-meter mh-meter--thin" data-tone="settled" style="--mh-meter-value: .75; --mh-meter-cells: 8"><div class="mh-meter__head"><span class="mh-label">SSUs online · thin</span><span class="mh-num">6 / 8</span></div><div class="mh-meter__bar"></div></div>
    </div>`);
  },
};

const splitHtml = ({ label, aria, parts }) => {
  const total = parts.reduce((s, p) => s + p.value, 0);
  const pct = (v) => `${((v / total) * 100).toFixed(2)}%`;
  return `<div class="mh-split">
    <span class="mh-label">${label}</span>
    <div class="mh-plate mh-plate--xs mh-split__bar" role="img" aria-label="${aria ?? parts.map((p) => `${p.name} ${pct(p.value)}`).join(", ")}">
      ${parts.map((p) => `<span data-tone="${p.tone}" style="--share:${p.value}"></span>`).join("")}
    </div>
    <ul class="mh-split__legend">${parts.map((p) => `<li data-tone="${p.tone}"><span>${p.name}</span><b class="mh-num">${p.display ?? int.format(p.value)}</b><small>${pct(p.value)}</small></li>`).join("")}</ul>
  </div>`;
};

export const Split = {
  parameters: describe(
    null,
    "`.mh-split`: shares of one amount on a single plate. The reward split is fixed in basis points at listing; the hauler takes `floor(reward × bps / 10,000)` and the treasury the rest. Tones: accent, brand, a, b, hatch, ok, alert.",
  ),
  argTypes: {
    job: { table: { disable: true } },
    reward: { control: { type: "number", min: 1, step: 50 } },
    haulerBps: { name: "hauler share (bps)", control: { type: "range", min: 0, max: 10000, step: 50 } },
  },
  args: { reward: 23750, haulerBps: 8500 },
  render: ({ reward, haulerBps }) => {
    const hauler = Math.floor((reward * haulerBps) / 10000);
    const live = JOBS.filter((j) => j.status !== "open");
    const openRewards = JOBS.filter((j) => j.status === "open").reduce((s, j) => s + j.reward, 0);
    const liveRewards = live.reduce((s, j) => s + j.reward, 0);
    const collateral = live.reduce((s, j) => s + (j.collateral ?? 0), 0);
    return render(`<div class="sb-stack" style="max-width: 640px">
      ${splitHtml({ label: `Reward split · ${int.format(reward)} CR`, parts: [
        { name: "Hauler", tone: "accent", value: hauler, display: `${int.format(hauler)} CR` },
        { name: "Treasury", tone: "brand", value: reward - hauler, display: `${int.format(reward - hauler)} CR` },
      ] })}
      ${splitHtml({ label: `Escrow composition · ${int.format(openRewards + liveRewards + collateral)} CR`, parts: [
        { name: "Rewards on open listings", tone: "a", value: openRewards, display: `${int.format(openRewards)} CR` },
        { name: "Rewards on live hauls", tone: "accent", value: liveRewards, display: `${int.format(liveRewards)} CR` },
        { name: "Hauler collateral", tone: "hatch", value: collateral, display: `${int.format(collateral)} CR` },
      ] })}
      ${splitHtml({ label: "Dispute resolution against the hauler · 13,000 CR collateral", parts: [
        { name: "To lister (collateral fraction)", tone: "alert", value: 6500, display: "6,500 CR" },
        { name: "To treasury", tone: "brand", value: 6500, display: "6,500 CR" },
      ] })}
    </div>`);
  },
};

const endpoint = ({ role, ssu, name, mode, note, risk }) => `<div class="mh-plate mh-plate--sm mh-endpoint" data-mode="${mode}"${risk ? " data-risk" : ""}>
  <span class="mh-label">${role}</span><b>${ssu}</b><span>${name}</span><span class="mh-endpoint__mode">${note}</span>
</div>`;

export const Route = {
  argTypes: { job: { table: { disable: true } } },
  parameters: describe(
    null,
    "`.mh-route`: a Transfer's two endpoint SSUs. The dashed link is schematic: Minehaul does not prescribe or attest the travel path. Leased endpoints show the lease end in the warning colour, and `data-risk` outlines one whose lease ends before the haul deadline. Below 520px the route stacks vertically.",
  ),
  render: () =>
    render(`<div class="sb-stack" style="max-width: 760px">
      <div class="mh-route">${endpoint({ role: "Source", ssu: "SSU-01", name: "Aster Prime", mode: "vaulted", note: "Vaulted" })}<div class="mh-route__link" aria-hidden="true"><span>endpoint only</span></div>${endpoint({ role: "Destination", ssu: "SSU-04", name: "Meridian Outpost", mode: "vaulted", note: "Vaulted" })}</div>
      <div class="mh-route">${endpoint({ role: "Source", ssu: "SSU-04", name: "Meridian Outpost", mode: "vaulted", note: "Vaulted" })}<div class="mh-route__link" aria-hidden="true"><span>endpoint only</span></div>${endpoint({ role: "Destination", ssu: "SSU-05", name: "Kepler Station", mode: "leased", note: "Leased · ends 23 Oct 08:00" })}</div>
      <div class="mh-route">${endpoint({ role: "Source", ssu: "SSU-02", name: "Halcyon Depot", mode: "vaulted", note: "Vaulted" })}<div class="mh-route__link" aria-hidden="true"><span>endpoint only</span></div>${endpoint({ role: "Destination", ssu: "SSU-03", name: "Cinder Relay", mode: "leased", note: "Lease ends before deadline", risk: true })}</div>
    </div>`, { style: "--_route-bg: var(--mh-bg)" }),
};
