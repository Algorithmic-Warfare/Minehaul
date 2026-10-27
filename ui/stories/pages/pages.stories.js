import { render, describe, icon, identicon, int } from "../_lib.js";
import { renderStacks } from "../../js/stacks.js";
import { renderJobCard, rate, units, minCollateral, formatTime } from "../../js/job.js";
import { JOBS, ENDED, NOW, NETWORKS } from "../../demo/jobs.js";
import { NETWORK_DETAIL, CHARACTERS, EVENTS, short } from "../../demo/network.js";
import { boardConfig, escrowConfig } from "../data/_boards.js";
import { networkCard, ssuCard, feedHtml } from "../display/_network.js";
import { SSUS } from "../../demo/network.js";

const ME = CHARACTERS.vex;
const BALANCE = 184250;
let uid = 0;

/* Layout for the page stories only. Scoped by .pg so it never leaks into components. */
const PAGE_CSS = `<style>
  .pg { min-height: 100vh; background: var(--mh-bg); color: var(--mh-fg); }
  .pg__body { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--mh-space-6); max-width: 1440px; margin: 0 auto; padding: var(--mh-space-6) max(16px, env(safe-area-inset-right, 0px)) var(--mh-space-8) max(16px, env(safe-area-inset-left, 0px)); }
  .pg__head { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; gap: var(--mh-space-4); }
  .pg__title { margin: 0; font: 700 clamp(1.6rem, 1.2rem + 1.6vw, 2.4rem) / 1.05 var(--mh-font-display); letter-spacing: -0.02em; }
  .pg__lede { margin: 6px 0 0; max-width: 64ch; font-size: var(--mh-text-sm); color: var(--mh-muted); }
  .pg__toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: var(--mh-space-3); }
  .pg__panel { --mh-plate-fill: var(--mh-bg); display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--mh-space-5); min-width: 0; padding: var(--mh-space-5); }
  .pg__two { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--mh-space-5); align-items: start; }
  .pg__side { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--mh-space-5); min-width: 0; }
  .pg__stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: var(--mh-space-4); }
  .pg__cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 260px), 1fr)); gap: var(--mh-space-4); }
  .pg h2 { margin: 0; font: 700 var(--mh-text-xl) / 1.15 var(--mh-font-display); }
  @media (min-width: 1200px) {
    .pg__two { grid-template-columns: minmax(0, 1fr) minmax(360px, 440px); }
    .pg__two--wide-side { grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr); }
    .pg__side--sticky { position: sticky; top: 80px; }
  }
  @media (max-width: 640px) {
    .pg .mh-topbar__brand span:not(.mh-mark) { display: none; }
    /* Visually hidden, so the wallet keeps its accessible name */
    .pg .mh-wallet > span { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
    .pg .mh-topbar { gap: var(--mh-space-3); }
  }
</style>`;

const NAV = [
  ["board", "Board", JOBS.filter((j) => j.status === "open").length],
  ["hauls", "My hauls", JOBS.filter((j) => j.mine && j.status !== "open").length],
  ["networks", "Networks", NETWORK_DETAIL.length],
  ["activity", "Activity", null],
];

const topbar = (current) => `<header class="mh-topbar">
  <a class="mh-topbar__brand" href="#board" aria-label="Minehaul home"><span class="mh-mark" aria-hidden="true">${"<i></i>".repeat(9)}</span><span>Minehaul</span></a>
  <nav class="mh-topbar__nav" aria-label="Primary"><ul class="mh-navlist">${NAV.map(
    ([key, label, count]) =>
      `<li><a class="mh-plate mh-navitem" href="#${key}"${key === current ? ' aria-current="page"' : ""}><span class="mh-lamp" aria-hidden="true"></span>${label}${count != null ? ` <span class="mh-count">${count}</span>` : ""}</a></li>`,
  ).join("")}</ul></nav>
  <div class="mh-topbar__actions">
    <span class="mh-badge-wrap"><button type="button" class="mh-plate mh-iconbtn" aria-label="Notifications, 2 new">${icon("bell")}</button><span class="mh-count" aria-hidden="true">2</span></span>
    <button type="button" class="mh-plate mh-wallet">${identicon(ME.address, { size: 28 })}<span>${ME.name}<small>${int.format(BALANCE)} CR · ${short(ME.address, 4, 4)}</small></span></button>
  </div>
</header>`;

const pausedBanner = () => {
  const org = NETWORK_DETAIL.find((n) => n.paused);
  return `<div class="mh-banner mh-banner--hatch" data-tone="warn" data-mh-dismissible role="status">
    <span class="mh-banner__icon">${icon("pause")}</span>
    <p class="mh-banner__text" style="margin: 0"><b>${org.name} is paused.</b> ${org.pausedNote} Existing hauls can still finish and settle.</p>
    <button type="button" class="mh-link">View proposal</button>
    <button type="button" class="mh-toast__close" data-mh-dismiss aria-label="Dismiss banner">${icon("cross")}</button>
  </div>`;
};

const crumbs = (items) => `<nav class="mh-crumbs" aria-label="Breadcrumb"><ol>${items
  .map(([label, href], i) => (i === items.length - 1 ? `<li aria-current="page">${label}</li>` : `<li><a href="${href}">${label}</a></li>`))
  .join("")}</ol></nav>`;

const jobsTable = (jobs, selected) => `<div class="mh-table-scroll"><table class="mh-table">
  <caption class="mh-sr">Open Transfer jobs</caption>
  <thead><tr><th>Job</th><th>Route</th><th>Cargo</th><th class="mh-table__num">Units</th><th class="mh-table__num">Reward</th><th class="mh-table__num">Rate</th><th class="mh-table__num">Min collateral</th></tr></thead>
  <tbody>${jobs
    .map(
      (j) => `<tr data-job="${j.id}"${j.id === selected ? ' aria-selected="true"' : ""}>
      <td><button type="button" class="mh-link" data-open-job="${j.id}" style="text-transform: none; letter-spacing: 0">${j.id}</button> <span class="mh-plate mh-plate--xs mh-tag" title="${j.network.name}">${j.network.tag}</span></td>
      <td class="mh-table__id">${j.source.ssu} → ${j.destination.ssu}</td>
      <td style="font-family: var(--mh-font-body)">${j.manifest[0].label}${j.manifest.length > 1 ? ` +${j.manifest.length - 1}` : ""}${j.risk ? ` <span style="color: var(--mh-warn)">${icon("warning", { label: j.risk })}</span>` : ""}</td>
      <td class="mh-table__num">${int.format(units(j))}</td><td class="mh-table__num">${int.format(j.reward)}</td>
      <td class="mh-table__num">${rate(j).toFixed(2)}</td><td class="mh-table__num">${int.format(minCollateral(j))}</td>
    </tr>`,
    )
    .join("")}</tbody>
</table></div>`;

const stat = (label, value, unit, note) => `<div class="mh-plate mh-stat"><span class="mh-label">${label}</span><b class="mh-stat__value">${value}${unit ? `<small>${unit}</small>` : ""}</b>${note ? `<span class="mh-stat__delta">${note}</span>` : ""}</div>`;

export default {
  title: "Pages",
  parameters: { layout: "fullscreen", ...describe("Whole Minehaul screens composed only from library components, with fictional demo data. They show how the parts fit, and they hold up from 390px phones to wide desktops.") },
};

/* ---------- Job board ---------- */

export const JobBoard = {
  name: "Job board",
  parameters: describe(null, "Top bar with interlocking nav and wallet, a paused-network banner, filters, the board as countable stacks, and the same jobs as a table. Selecting a job anywhere opens its card beside the board on wide screens and below it on narrow ones. Search and the network filter re-render both views."),
  render: () => {
    const open = JOBS.filter((j) => j.status === "open");
    const page = render(`${PAGE_CSS}<div class="pg">
      ${topbar("board")}
      ${pausedBanner()}
      <main class="pg__body">
        <div class="pg__head">
          <div><h1 class="pg__title">Open board</h1><p class="pg__lede">${open.length} funded Transfers across ${NETWORK_DETAIL.length} networks. Claiming posts collateral in the reward asset; the minimum is a share of the reward, not a valuation of the cargo.</p></div>
        </div>
        <div class="pg__toolbar" role="search">
          <label class="mh-plate mh-field" style="flex: 1 1 260px"><span class="mh-field__prefix">${icon("search")}</span><input type="search" data-search placeholder="Search jobs, SSUs or cargo" aria-label="Search jobs, SSUs or cargo"></label>
          <div class="mh-seg" role="group" aria-label="Network" data-network>
            <button type="button" data-net="all" aria-pressed="true">All</button>
            ${Object.values(NETWORKS).map((n) => `<button type="button" data-net="${n.tag}" aria-pressed="false" title="${n.name}">${n.tag}</button>`).join("")}
          </div>
          <label class="mh-plate mh-field mh-select" style="min-height: 36px"><span class="mh-field__prefix">Sort</span><select data-sort aria-label="Sort table by">
            <option value="rate">Reward rate</option><option value="reward">Reward</option><option value="units">Cargo units</option><option value="collateral">Min collateral</option>
          </select></label>
        </div>
        <div class="pg__two">
          <div class="pg__side">
            <div class="mh-plate mh-plate--lg pg__panel"><div data-stacks></div></div>
            <section class="sb-section" aria-labelledby="pg-list-h"><h2 id="pg-list-h">All open jobs</h2><div data-table></div></section>
          </div>
          <aside class="pg__side pg__side--sticky" aria-label="Selected job" data-card aria-live="polite"></aside>
        </div>
      </main>
    </div>`);

    const state = { net: "all", q: "", sort: "rate", selected: "MH-0230" };
    const sorts = { rate: (a, b) => rate(b) - rate(a), reward: (a, b) => b.reward - a.reward, units: (a, b) => units(b) - units(a), collateral: (a, b) => minCollateral(b) - minCollateral(a) };
    const visible = () =>
      open.filter((j) => {
        if (state.net !== "all" && j.network.tag !== state.net) return false;
        const hay = `${j.id} ${j.source.ssu} ${j.source.name} ${j.destination.ssu} ${j.destination.name} ${j.manifest.map((l) => l.label).join(" ")}`.toLowerCase();
        return !state.q || hay.includes(state.q);
      });
    const card = page.querySelector("[data-card]");
    const show = (job) => {
      state.selected = job.id;
      card.innerHTML = renderJobCard(job, { now: NOW, headingLevel: 2 });
      for (const tr of page.querySelectorAll("tr[data-job]")) {
        if (tr.dataset.job === job.id) tr.setAttribute("aria-selected", "true");
        else tr.removeAttribute("aria-selected");
      }
      board?.select(job.id);
    };
    let board;
    const update = () => {
      const items = visible();
      const host = document.createElement("div");
      page.querySelector("[data-stacks]").replaceWith(host);
      host.dataset.stacks = "";
      board = renderStacks(host, { ...boardConfig({ items, selected: state.selected, onSelect: show }), headingLevel: 2 });
      page.querySelector("[data-table]").innerHTML = items.length
        ? jobsTable([...items].sort(sorts[state.sort]), state.selected)
        : `<div class="mh-empty"><span class="mh-empty__icon">${icon("filter", { size: 28 })}</span><p class="mh-empty__title">No jobs match</p><p>Clear the search or pick another network.</p></div>`;
    };

    page.querySelector("[data-search]").addEventListener("input", (e) => { state.q = e.target.value.trim().toLowerCase(); update(); });
    page.querySelector("[data-sort]").addEventListener("change", (e) => { state.sort = e.target.value; update(); });
    page.querySelector("[data-network]").addEventListener("click", (e) => {
      const b = e.target.closest("[data-net]");
      if (!b) return;
      state.net = b.dataset.net;
      for (const x of page.querySelectorAll("[data-net]")) x.setAttribute("aria-pressed", String(x === b));
      update();
    });
    page.addEventListener("click", (e) => {
      const b = e.target.closest("[data-open-job]");
      if (b) show(JOBS.find((j) => j.id === b.dataset.openJob));
    });

    update();
    show(JOBS.find((j) => j.id === state.selected));
    return page;
  },
};

/* ---------- Haul detail ---------- */

export const HaulDetail = {
  name: "Haul detail",
  parameters: describe(null, "One of the viewer's hauls mid-delivery: breadcrumbs, a live deadline countdown, the job card, the delivery transaction waiting on a wallet signature, notices and the job's own events."),
  render: () => {
    const job = JOBS.find((j) => j.id === "MH-0246");
    const deadline = job.claimedAt + job.haulDurationMs;
    const events = [
      { event: "claimed", name: "ActionClaimed", job: job.id, actor: ME, at: job.claimedAt, tx: "0x5a1c…77e0", note: `${int.format(job.collateral)} CR collateral` },
      { event: "listed", name: "ActionListed", job: job.id, actor: CHARACTERS.ilse, at: job.listedAt, tx: "0x0f93…b2c4", note: `${int.format(job.reward)} CR reward · ${int.format(units(job))} u` },
    ];
    return render(`${PAGE_CSS}<div class="pg">
      ${topbar("hauls")}
      <main class="pg__body">
        <div class="pg__head">
          <div class="sb-stack" style="gap: 8px">
            ${crumbs([["My hauls", "#hauls"], [job.network.name, "#networks"], [job.id, ""]])}
            <h1 class="pg__title">Deliver ${job.id} to ${job.destination.ssu}</h1>
          </div>
          <div class="sb-stack" style="gap: 4px; justify-items: end">
            <span class="mh-label">Haul deadline</span>
            <span class="mh-countdown" role="timer" data-mh-countdown="${deadline}" data-now="${NOW}" data-warn-under="${3 * 3_600_000}" data-alert-under="${2 * 3_600_000}"></span>
          </div>
        </div>
        <div class="pg__two">
          <div class="pg__side">${renderJobCard(job, { now: NOW, headingLevel: 2 })}</div>
          <div class="pg__side">
            <section class="mh-plate pg__panel" aria-labelledby="pg-tx-h">
              <h2 id="pg-tx-h">Delivery transaction</h2>
              <ol class="mh-txflow" aria-label="Transaction progress">
                <li data-state="done"><span class="mh-txflow__cell">${icon("check")}</span>Build</li>
                <li data-state="active" aria-current="step"><span class="mh-txflow__cell"><span class="mh-spinner" aria-hidden="true">${"<i></i>".repeat(9)}</span></span>Sign</li>
                <li data-state="todo"><span class="mh-txflow__cell">3</span>Submit</li>
                <li data-state="todo"><span class="mh-txflow__cell">4</span>Confirm</li>
              </ol>
              <div class="mh-plate mh-notice" data-tone="info"><span class="mh-notice__icon">${icon("wallet")}</span><span class="mh-notice__title">Waiting for your wallet</span><p>Approve the transaction in your wallet. It withdraws the full manifest with a delivery request bound to ${job.destination.ssu}; the adapter must certify delivery in the same transaction or nothing commits.</p></div>
              <div class="sb-row"><button type="button" class="mh-plate mh-button mh-button--ghost mh-button--sm"><span class="mh-button__label">Cancel signing</span></button></div>
            </section>
            <div class="mh-plate mh-notice" data-tone="warn"><span class="mh-notice__icon">${icon("warning")}</span><span class="mh-notice__title">Destination is leased</span><p>${job.destination.ssu} ${job.destination.name}'s lease ends ${formatTime(job.destination.leaseEndsAt)}, after your deadline. If it lapses first, delivery fails admission.</p></div>
            <section class="sb-section" aria-labelledby="pg-feed-h">
              <h2 id="pg-feed-h">Events</h2>
              ${feedHtml(events)}
              <p class="sb-caption">Collection is recorded in the job's status and emits no event.</p>
            </section>
          </div>
        </div>
      </main>
    </div>`);
  },
};

/* ---------- Network overview ---------- */

export const NetworkOverview = {
  name: "Network overview",
  parameters: describe(null, "A network operator's view of Meridian Union: headline figures, the network card, its endpoint SSUs, escrow by stage for this network only, adapters and activity."),
  render: () => {
    const net = NETWORK_DETAIL.find((n) => n.tag === "MRD");
    const jobs = JOBS.filter((j) => j.network.tag === net.tag);
    const escrow = jobs.reduce((s, j) => s + j.reward + (j.status === "open" ? 0 : j.collateral ?? 0), 0);
    const feed = EVENTS.filter((e) => e.job === net.tag || jobs.some((j) => j.id === e.job));
    const page = render(`${PAGE_CSS}<div class="pg">
      ${topbar("networks")}
      <main class="pg__body">
        <div class="pg__head"><div class="sb-stack" style="gap: 8px">${crumbs([["Networks", "#networks"], [net.name, ""]])}<h1 class="pg__title">${net.name}</h1></div>
          <button type="button" class="mh-plate mh-button mh-button--brand"><span class="mh-button__label">New proposal</span></button></div>
        <div class="pg__stats">
          ${stat("Escrow held", int.format(escrow), "CR", `${jobs.length} jobs`)}
          ${stat("Open jobs", jobs.filter((j) => j.status === "open").length, "", "claimable now")}
          ${stat("Live hauls", jobs.filter((j) => !["open", "settled"].includes(j.status)).length, "", "claimed or collected")}
          ${stat("Endpoints", net.ssus.length, "SSUs", `${net.ssus.filter((s) => SSUS[s].mode === "leased").length} leased`)}
        </div>
        <div class="pg__two pg__two--wide-side">
          ${networkCard(net, 2)}
          <div class="pg__cards">${net.ssus.map(ssuCard).join("")}</div>
        </div>
        <div class="mh-plate mh-plate--lg pg__panel" style="--mh-data-match: var(--mh-brand-fill)"><div data-stacks></div></div>
        <div class="pg__two">
          <section class="sb-section" aria-labelledby="pg-act-h"><h2 id="pg-act-h">Activity</h2>${feed.length ? feedHtml(feed) : `<p class="sb-caption">No events yet.</p>`}</section>
          <section class="sb-section" aria-labelledby="pg-ad-h"><h2 id="pg-ad-h">Delivery adapters</h2>
            ${net.adapters.map((a) => `<div class="mh-plate pg__panel" style="gap: 8px; padding: var(--mh-space-4)"><div class="sb-row" style="justify-content: space-between"><b>${icon("adapter")} ${a.name}</b><span class="mh-plate mh-plate--xs mh-status" data-status="${a.status === "revoked" ? "cancelled" : "delivered"}">${a.status === "revoked" ? "Revoked" : "Test only"}</span></div><span class="mh-id"><span class="mh-id__label">Auth</span><code>${a.id}</code></span></div>`).join("")}
            <div class="mh-plate mh-notice" data-tone="info"><span class="mh-notice__icon">${icon("info")}</span><span class="mh-notice__title">No production adapter yet</span><p>Deliveries on this network are certified by a test-only adapter. Passing an SSU ownership witness is not proof of delivery.</p></div>
          </section>
        </div>
      </main>
    </div>`);
    renderStacks(page.querySelector("[data-stacks]"), { ...escrowConfig({ items: jobs, per: 1000, title: `Escrow held · ${net.name}` }), headingLevel: 2 });
    return page;
  },
};

/* ---------- My hauls ---------- */

export const MyHauls = {
  name: "My hauls",
  parameters: describe(null, "Tabs over the viewer's hauls: live ones (claimed, collected, in the dispute window) and ended ones. Arrow keys move between tabs."),
  render: () => {
    const id = ++uid;
    const live = JOBS.filter((j) => j.mine && j.status !== "open");
    const ended = ENDED.filter((j) => j.mine);
    const cards = (list) => `<div class="sb-stack">${list.map((j) => renderJobCard(j, { now: NOW, headingLevel: 2 })).join("")}</div>`;
    return render(`${PAGE_CSS}<div class="pg">
      ${topbar("hauls")}
      <main class="pg__body" style="max-width: 1040px">
        <div class="pg__head"><div><h1 class="pg__title">My hauls</h1><p class="pg__lede">${ME.name} · ${int.format(live.reduce((s, j) => s + (j.collateral ?? 0), 0))} CR collateral posted across ${live.length} live hauls.</p></div></div>
        <div class="mh-tabs" data-mh-tabs>
          <div class="mh-tabs__list" role="tablist" aria-label="My hauls">
            <button type="button" class="mh-tab" role="tab" id="mh-live-${id}" aria-controls="mh-live-p-${id}" aria-selected="true">Live <span class="mh-count">${live.length}</span></button>
            <button type="button" class="mh-tab" role="tab" id="mh-ended-${id}" aria-controls="mh-ended-p-${id}" aria-selected="false">Ended <span class="mh-count">${ended.length}</span></button>
          </div>
          <div class="mh-tabpanel" role="tabpanel" id="mh-live-p-${id}" aria-labelledby="mh-live-${id}" tabindex="0">${cards(live)}</div>
          <div class="mh-tabpanel" role="tabpanel" id="mh-ended-p-${id}" aria-labelledby="mh-ended-${id}" tabindex="0" hidden>${ended.length ? cards(ended) : `<div class="mh-empty"><p class="mh-empty__title">No ended hauls</p></div>`}</div>
        </div>
      </main>
    </div>`);
  },
};
