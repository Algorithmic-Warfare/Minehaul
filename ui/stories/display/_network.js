import { icon, identicon, int } from "../_lib.js";
import { JOBS, NOW } from "../../demo/jobs.js";
import { SSUS, short, ago } from "../../demo/network.js";
import { meterHtml, formatTime, formatSpan } from "../../js/job.js";

/* Network markup shared by Display/Network and the Pages stories. Not a story file. */

export const escrowOf = (tag) =>
  JOBS.filter((j) => j.network.tag === tag).reduce((s, j) => s + j.reward + (j.status === "open" ? 0 : j.collateral ?? 0), 0);

export const nodesHtml = (ids, { live = true } = {}) => `<ul class="mh-nodes" aria-label="Endpoint SSUs">${ids
  .map((id) => {
    const s = SSUS[id];
    const state = s.off ? " data-off" : live && s.live ? " data-live" : "";
    return `<li><span class="mh-node" data-mode="${s.mode}"${state}></span><b>${s.ssu}</b><span>${s.name}</span><span>${s.off ? "offline" : s.mode}</span></li>`;
  })
  .join("")}</ul>`;

export const networkCard = (n, level = 3) => {
  const jobs = JOBS.filter((j) => j.network.tag === n.tag);
  return `<article class="mh-plate mh-plate--lg mh-network"${n.paused ? " data-paused" : ""} aria-label="${n.name}">
    <div class="mh-network__head">
      <div><span class="mh-label">Network · ${n.tag}</span><h${level} class="mh-network__name">${n.name}</h${level}></div>
      <span class="mh-plate mh-plate--xs mh-tag"><span class="mh-lamp mh-lamp--sm" data-lit style="--_lamp: var(${n.paused ? "--mh-warn" : "--mh-ok"})"></span>${n.paused ? "Paused" : "Live"}</span>
    </div>
    <p>${n.description}</p>
    ${n.paused ? `<div class="mh-plate mh-notice" data-tone="warn"><span class="mh-notice__icon">${icon("pause")}</span><span class="mh-notice__title">New claims are blocked</span><p>${n.pausedNote} Existing hauls can still finish and settle.</p></div>` : ""}
    <div class="mh-network__figures">
      <div><span class="mh-label">SSUs</span><b>${n.ssus.length}</b></div>
      <div><span class="mh-label">Open jobs</span><b>${jobs.filter((j) => j.status === "open").length}</b></div>
      <div><span class="mh-label">Escrow</span><b>${int.format(escrowOf(n.tag))}</b></div>
      <div><span class="mh-label">Min collateral</span><b>${(n.config.minCollateralRatioBps / 100).toFixed(0)}%</b></div>
      <div><span class="mh-label">Dispute window</span><b>${formatSpan(n.config.disputeWindowMs)}</b></div>
    </div>
    ${nodesHtml(n.ssus)}
    <div class="sb-row" style="gap: 8px"><span class="mh-label">Treasury</span>
      <span class="mh-id">${identicon(n.treasury, { size: 20 })}<code title="${n.treasury}">${short(n.treasury)}</code><button type="button" class="mh-id__copy" data-mh-copy="${n.treasury}" aria-label="Copy ${n.name} treasury address">${icon("copy")}</button></span>
    </div>
  </article>`;
};

export const ssuCard = (id) => {
  const s = SSUS[id];
  const leased = s.mode === "leased";
  return `<article class="mh-plate mh-ssu" data-mode="${s.mode}" aria-label="${s.ssu} ${s.name}">
    <div class="mh-ssu__head">
      <div><div class="mh-ssu__id">${s.ssu}</div><div class="mh-ssu__name">${s.name}</div></div>
      <span class="mh-plate mh-plate--xs mh-tag"><span class="mh-lamp mh-lamp--sm"${s.off ? "" : ` data-lit style="--_lamp: var(${leased ? "--mh-warn" : "--mh-ok"})"`}></span>${s.off ? "Offline" : leased ? "Leased" : "Vaulted"}</span>
    </div>
    <div class="mh-ssu__owner">${identicon(s.owner.address, { size: 21 })}<span>Owner <b>${s.owner.name}</b></span></div>
    ${leased ? meterHtml({ label: "Lease", start: s.leaseStartedAt, end: s.leaseEndsAt, now: NOW, tone: "deadline", foot: [`Started ${formatTime(s.leaseStartedAt)}`, `Ends ${formatTime(s.leaseEndsAt)}`] }) : `<p class="sb-caption">OwnerCap held in the DAO capability vault.</p>`}
    <dl class="mh-kv"><div><dt>Registered</dt><dd>${formatTime(s.registeredAt)}</dd></div></dl>
  </article>`;
};

export const feedHtml = (events) => `<ol class="mh-feed">${events
  .map(
    (e) => `<li class="mh-feed__item" data-event="${e.event}"${e.fresh ? " data-new" : ""}>
    <span class="mh-feed__mark" aria-hidden="true"></span>
    <span class="mh-feed__event">${e.name} <span style="color: var(--mh-fg); font-weight: 400">${e.job}</span></span>
    <time class="mh-feed__time" datetime="${new Date(e.at).toISOString()}">${ago(e.at)}</time>
    <div class="mh-feed__detail">
      ${e.actor ? `<span class="sb-row" style="gap: 6px">${identicon(e.actor.address, { size: 14 })}${e.actor.name}</span>` : "<span>Protocol</span>"}
      <span>${e.note}</span>
      <span class="mh-id"><span class="mh-id__label">Tx</span><code>${e.tx}</code></span>
    </div>
  </li>`,
  )
  .join("")}</ol>`;

