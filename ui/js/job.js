/**
 * Job card: renders one Transfer from a record shaped after
 * minehaul_core::action::HaulAction. Returns an HTML string that uses only
 * library classes, so the same markup can come from a server or framework.
 *
 * Record fields (times in ms since epoch):
 *   id, network { tag, name }, source / destination { ssu, name, mode, leaseEndsAt? },
 *   manifest [{ label, collection, asset, qty }], reward, rewardAsset,
 *   rewardToHaulerBps, minCollateralRatioBps, collateral?,
 *   status (open|claimed|collected|delivered|settled|disputed|resolved|expired|cancelled),
 *   exitFrom? (the stage a dispute, expiry or cancellation left from),
 *   listedAt, listingExpiresAt, claimedAt?, collectedAt?, deliveredAt?, settledAt?,
 *   haulDurationMs, disputeWindowMs, mine?
 */

const esc = (value) =>
  String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const int = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });
const HOUR = 3_600_000;

export const STAGES = [
  { key: "open", label: "Listed", at: "listedAt" },
  { key: "claimed", label: "Claimed", at: "claimedAt" },
  { key: "collected", label: "Collected", at: "collectedAt" },
  { key: "delivered", label: "Delivered", at: "deliveredAt" },
  { key: "settled", label: "Settled", at: "settledAt" },
];

const EXITS = { disputed: "Disputed", resolved: "Resolved", expired: "Expired", cancelled: "Cancelled" };

export const units = (job) => job.manifest.reduce((sum, line) => sum + line.qty, 0);
export const rate = (job) => job.reward / units(job);
/** The protocol rounds the minimum collateral up and never allows zero. */
export const minCollateral = (job) => Math.max(1, Math.ceil((job.reward * job.minCollateralRatioBps) / 10_000));

export function formatTime(ms) {
  const d = new Date(ms);
  const day = d.toLocaleString("en-GB", { day: "2-digit", month: "short", timeZone: "UTC" });
  const time = d.toLocaleString("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone: "UTC" });
  return `${day} ${time}`;
}

export function formatSpan(ms) {
  const m = Math.max(0, Math.round(ms / 60_000));
  const h = Math.floor(m / 60);
  return h >= 48 ? `${Math.floor(h / 24)}d ${h % 24}h` : h ? `${h}h ${String(m % 60).padStart(2, "0")}m` : `${m}m`;
}

export function trackHtml(job) {
  const exit = EXITS[job.status];
  const reached = exit ? job.exitFrom ?? "open" : job.status;
  const index = STAGES.findIndex((s) => s.key === reached);
  const settled = job.status === "settled";
  const visible = exit ? STAGES.slice(0, index + 1) : STAGES;
  const steps = visible.map((stage, i) => {
    const step = settled || i < index || (exit && i === index) ? "done" : i === index ? "current" : "todo";
    const when = job[stage.at] ? `<small>${esc(formatTime(job[stage.at]))}</small>` : "";
    return `<li class="mh-plate mh-track__step" data-step="${step}"${step === "current" ? ' aria-current="step"' : ""}><span class="mh-lamp" aria-hidden="true"></span><span>${stage.label}${when}</span></li>`;
  });
  if (exit) {
    steps.push(`<li class="mh-plate mh-track__step mh-track__exit" data-status="${job.status}" aria-current="step"><span class="mh-lamp" aria-hidden="true"></span><span>${exit}<small>${esc(job.exitNote ?? "")}</small></span></li>`);
  }
  // Focusable so keyboard users can scroll the track when it overflows
  return `<div class="mh-track-scroll" tabindex="0" role="group" aria-label="Lifecycle, scrollable"><ol class="mh-track" aria-label="Lifecycle"${settled ? ' data-outcome="settled"' : ""}>${steps.join("")}</ol></div>`;
}

export function meterHtml({ label, start, end, now, tone, foot }) {
  const total = end - start;
  const value = Math.min(1, Math.max(0, (now - start) / total));
  const hours = total / HOUR;
  const cells = Math.max(4, Math.min(48, Math.round(hours)));
  const left = end - now;
  const toneNow = tone === "deadline" && value > 0.75 ? "alert" : tone;
  return `<div class="mh-meter" data-tone="${toneNow}" style="--mh-meter-value:${value.toFixed(4)};--mh-meter-cells:${cells}"
      role="meter" aria-label="${esc(label)}" aria-valuemin="0" aria-valuemax="${hours.toFixed(1)}" aria-valuenow="${(value * hours).toFixed(1)}" aria-valuetext="${esc(left > 0 ? `${formatSpan(left)} left` : "ended")}">
    <div class="mh-meter__head"><span class="mh-label">${esc(label)}</span><span class="mh-num">${left > 0 ? `${esc(formatSpan(left))} left` : "Ended"}</span></div>
    <div class="mh-meter__bar"></div>
    <div class="mh-meter__foot">${foot.map((f) => `<span>${esc(f)}</span>`).join("")}</div>
  </div>`;
}

function timingHtml(job, now) {
  const meters = [];
  if (job.status === "open") {
    meters.push(meterHtml({ label: "Listing expires", start: job.listedAt, end: job.listingExpiresAt, now, tone: "deadline",
      foot: [`Listed ${formatTime(job.listedAt)}`, `Unclaimed refund ${formatTime(job.listingExpiresAt)}`] }));
  }
  if (job.status === "claimed" || job.status === "collected") {
    const end = job.claimedAt + job.haulDurationMs;
    meters.push(meterHtml({ label: "Haul deadline", start: job.claimedAt, end, now, tone: "deadline",
      foot: [`Claimed ${formatTime(job.claimedAt)}`, `Expiry opens a dispute ${formatTime(end)}`] }));
  }
  if (job.status === "delivered") {
    const end = job.deliveredAt + job.disputeWindowMs;
    meters.push(meterHtml({ label: "Dispute window", start: job.deliveredAt, end, now, tone: "window",
      foot: [`Delivered ${formatTime(job.deliveredAt)}`, `Anyone can finalize from ${formatTime(end)}`] }));
  }
  const share = job.rewardToHaulerBps;
  const hauler = Math.floor((job.reward * share) / 10_000);
  meters.push(`<div class="mh-split">
    <span class="mh-label">Reward split · fixed at listing</span>
    <div class="mh-plate mh-plate--xs mh-split__bar" role="img" aria-label="Hauler ${(share / 100).toFixed(2)}%, treasury ${((10_000 - share) / 100).toFixed(2)}%">
      <span data-tone="accent" style="--share:${share}"></span><span data-tone="brand" style="--share:${10_000 - share}"></span>
    </div>
    <ul class="mh-split__legend">
      <li data-tone="accent"><span>Hauler</span><b class="mh-num">${int.format(hauler)} ${esc(job.rewardAsset)}</b><small>${(share / 100).toFixed(2)}%</small></li>
      <li data-tone="brand"><span>Treasury</span><b class="mh-num">${int.format(job.reward - hauler)} ${esc(job.rewardAsset)}</b><small>${((10_000 - share) / 100).toFixed(2)}%</small></li>
    </ul>
  </div>`);
  return `<div class="mh-job__timing">${meters.join("")}</div>`;
}

function endpointHtml(role, end, now) {
  const leased = end.mode === "leased";
  const risk = leased && end.leaseEndsAt && end.leaseEndsAt - now < 24 * HOUR;
  const mode = leased ? `Leased${end.leaseEndsAt ? ` · ends ${formatTime(end.leaseEndsAt)}` : ""}` : "Vaulted";
  return `<div class="mh-plate mh-plate--sm mh-endpoint" data-mode="${leased ? "leased" : "vaulted"}"${risk ? " data-risk" : ""}>
    <span class="mh-label">${role}</span><b>${esc(end.ssu)}</b><span>${esc(end.name)}</span><span class="mh-endpoint__mode">${esc(mode)}</span>
  </div>`;
}

function actionsHtml(job, now) {
  const btn = (label, cls = "", extra = "") => `<button type="button" class="mh-plate mh-button ${cls}"${extra}><span class="mh-button__label">${esc(label)}</span><span class="mh-button__cells" aria-hidden="true"><i></i><i></i><i></i></span></button>`;
  switch (job.status) {
    case "open":
      return btn(`Claim · post ${int.format(minCollateral(job))} ${job.rewardAsset}`) + btn("Manifest", "mh-button--secondary");
    case "claimed":
      return btn("Confirm collection") + `<span class="mh-job__hint">Collect at ${esc(job.source.ssu)} first. Evidence stays outside the protocol.</span>`;
    case "collected":
      return btn(`Deliver to ${job.destination.ssu}`) + `<span class="mh-job__hint">Needs a delivery adapter to certify the handoff.</span>`;
    case "delivered": {
      const open = now >= job.deliveredAt + job.disputeWindowMs;
      return btn("Finalize", "", open ? "" : ' disabled') + btn("Open dispute", "mh-button--ghost") +
        `<span class="mh-job__hint">${open ? "Window closed. Anyone can finalize." : `Finalize unlocks ${esc(formatTime(job.deliveredAt + job.disputeWindowMs))}`}</span>`;
    }
    case "settled":
      return btn("View settlement", "mh-button--secondary") + `<span class="mh-job__hint">Paid to the fixed hauler and treasury addresses.</span>`;
    case "disputed":
      return btn("Add evidence", "mh-button--brand") + `<span class="mh-job__hint">Awaiting governance resolution.</span>`;
    default:
      return `<span class="mh-job__hint">Reward and any cargo still held returned to the lister.</span>`;
  }
}

export function renderJobCard(job, { now = Date.now(), headingLevel = 3 } = {}) {
  const h = Math.min(6, Math.max(1, headingLevel));
  const u = units(job);
  const collateralPosted = job.collateral != null && job.status !== "open";
  const min = minCollateral(job);
  const statusLabel = EXITS[job.status] ?? (job.status === "open" ? "Open" : STAGES.find((s) => s.key === job.status)?.label ?? job.status);
  const manifest = job.manifest
    .map((l) => `<tr><td>${esc(l.label)}</td><td class="mh-table__id">${esc(l.collection)}</td><td class="mh-table__num">${esc(l.asset)}</td><td class="mh-table__num">${int.format(l.qty)}</td></tr>`)
    .join("");
  return `<article class="mh-plate mh-plate--tl-br mh-plate--lg mh-job" aria-label="Transfer ${esc(job.id)}">
    <header class="mh-job__head">
      <div><span class="mh-label">Transfer · ${esc(job.id)}</span><h${h} class="mh-job__title">${esc(job.manifest[0].label)}${job.manifest.length > 1 ? ` and ${job.manifest.length - 1} more` : ""} · ${int.format(u)} u</h${h}></div>
      <div class="mh-job__tags">
        ${job.mine ? `<span class="mh-plate mh-plate--xs mh-tag" style="--mh-plate-fill: var(--mh-brand-fill); --mh-plate-keyline: var(--mh-brand-fill); color: var(--mh-brand-fg)">Your haul</span>` : ""}
        <span class="mh-plate mh-plate--xs mh-tag" title="${esc(job.network.name)}">${esc(job.network.tag)}</span>
        <span class="mh-plate mh-plate--xs mh-status" data-status="${esc(job.status)}">${esc(statusLabel)}</span>
      </div>
    </header>
    <div class="mh-route-host"><div class="mh-route">
      ${endpointHtml("Source", job.source, now)}
      <div class="mh-route__link" aria-hidden="true"><span>endpoint only</span></div>
      ${endpointHtml("Destination", job.destination, now)}
    </div></div>
    <dl class="mh-figures">
      <div class="mh-figure"><dt class="mh-label">Reward</dt><dd><span class="mh-figure__value">${int.format(job.reward)}</span><span class="mh-figure__unit">${esc(job.rewardAsset)}</span></dd></div>
      <div class="mh-figure"><dt class="mh-label">${collateralPosted ? "Collateral posted" : "Min collateral"}</dt><dd><span class="mh-figure__value">${int.format(collateralPosted ? job.collateral : min)}</span><span class="mh-figure__unit">${esc(job.rewardAsset)}</span><div class="mh-figure__note">${(job.minCollateralRatioBps / 100).toFixed(2)}% of reward, rounded up</div></dd></div>
      <div class="mh-figure"><dt class="mh-label">Rate</dt><dd><span class="mh-figure__value">${rate(job).toFixed(2)}</span><span class="mh-figure__unit">${esc(job.rewardAsset)}/u</span></dd></div>
      <div class="mh-figure"><dt class="mh-label">Haul window</dt><dd><span class="mh-figure__value">${esc(formatSpan(job.haulDurationMs))}</span><div class="mh-figure__note">Dispute window ${esc(formatSpan(job.disputeWindowMs))}</div></dd></div>
    </dl>
    ${trackHtml(job)}
    ${timingHtml(job, now)}
    <div class="mh-table-scroll"><table class="mh-table">
      <thead><tr><th>Cargo</th><th>Collection</th><th class="mh-table__num">Asset</th><th class="mh-table__num">Qty</th></tr></thead>
      <tbody>${manifest}</tbody>
      <tfoot><tr><td colspan="3">${job.manifest.length} line${job.manifest.length === 1 ? "" : "s"}</td><td class="mh-table__num">${int.format(u)}</td></tr></tfoot>
    </table></div>
    <footer class="mh-job__actions">${actionsHtml(job, now)}</footer>
  </article>`;
}
