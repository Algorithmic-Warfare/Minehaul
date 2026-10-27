import { render, icon, describe, int } from "../_lib.js";
import { createToaster } from "../../js/toast.js";
import { minCollateral, formatTime, formatSpan } from "../../js/job.js";
import { JOBS, NOW } from "../../demo/jobs.js";

const job0248 = JOBS.find((j) => j.id === "MH-0248");
const collateral = minCollateral(job0248);

let n = 0;
const uid = (p) => `${p}-${++n}`;

const ICONS = { info: "info", ok: "check", warn: "warning", alert: "alert", accent: "bell", brand: "shield" };
const spinner = (cls = "") => `<span class="mh-spinner ${cls}" aria-hidden="true">${"<i></i>".repeat(9)}</span>`;

export default {
  title: "Feedback",
  parameters: describe(
    "How Minehaul tells people what happened and what to do next. Every message has a tone (`data-tone`: info, ok, warn, alert, accent, brand) that sets the edge bar and icon colour. " +
      "Toasts confirm actions and transactions; banners carry page-wide state such as a paused network; notices explain a rule in place; dialogs confirm actions that post collateral. " +
      "Toast timers pause on hover and focus, and alert toasts use `role=\"alert\"`.",
  ),
  render: () => render(""),
};

/* ---------- Toast ---------- */

const toastMarkup = ({ tone, title, text, action, timer = true }) => `<div class="mh-plate mh-toast" data-tone="${tone}" style="--mh-toast-duration: 9s">
  <span class="mh-toast__icon">${icon(ICONS[tone])}</span>
  <div class="mh-toast__body">
    <span class="mh-toast__title">${title}</span>
    <p class="mh-toast__text">${text}</p>
    ${action ? `<div class="mh-toast__actions"><button type="button" class="mh-link">${action}</button></div>` : ""}
  </div>
  <button type="button" class="mh-toast__close" aria-label="Dismiss notification">${icon("cross")}</button>
  ${timer ? `<span class="mh-toast__timer" aria-hidden="true"></span>` : ""}
</div>`;

const MESSAGES = [
  { tone: "accent", title: "Claimed MH-0248", text: "Haul deadline 22 Oct 00:00. Collect at SSU-01 Aster Prime.", action: "View haul" },
  { tone: "ok", title: "Collateral posted", text: `${int.format(collateral)} CR held in escrow until settlement.` },
  { tone: "info", title: "Delivery certified", text: "MH-0242 delivered to SSU-08. The 24h dispute window is open.", action: "Track window" },
  { tone: "alert", title: "Dispute opened on MH-0233", text: "The lister disputed delivery. Reward and collateral stay escrowed until governance resolves it.", action: "Add evidence", timer: false },
  { tone: "warn", title: "Outer Rim Guild paused", text: "New claims are blocked. Existing hauls can still finish and settle." },
  { tone: "brand", title: "Lease ending on SSU-03", text: "Cinder Relay's lease ends 22 Oct 01:00, before MH-0238's haul deadline." },
];

export const Toast = {
  render: () =>
    render(`<div class="mh-toaster mh-toaster--inline" style="flex-direction: column">${MESSAGES.map(toastMarkup).join("")}</div>
      <p class="sb-caption" style="margin-top: var(--mh-space-4)">The draining cells show time left; hover a toast to pause them. Alerts that need action stay until dismissed (no timer).</p>`),
};

export const ToastLive = {
  name: "Toast · live",
  render: () => {
    const el = render(`<div class="sb-split">
      <div class="sb-stack" style="align-content: start">
        <span class="mh-label">Fire a toast</span>
        <div class="sb-row">
          ${MESSAGES.map((m, i) => `<button type="button" class="mh-plate mh-button mh-button--sm ${i ? "mh-button--secondary" : ""}" data-fire="${i}"><span class="mh-button__label">${m.tone}</span></button>`).join("")}
        </div>
        <p class="sb-caption">Uses <code>createToaster({ region })</code> from <code>js/toast.js</code> with an inline region, so toasts stay inside this story. In an app, call <code>createToaster()</code> once and it docks bottom-right.</p>
      </div>
      <section class="mh-toaster mh-toaster--inline" data-region style="min-height: 120px"></section>
    </div>`);
    const toaster = createToaster({ region: el.querySelector("[data-region]") });
    el.addEventListener("click", (e) => {
      const b = e.target.closest("[data-fire]");
      if (!b) return;
      const m = MESSAGES[Number(b.dataset.fire)];
      toaster.toast({
        tone: m.tone,
        title: m.title,
        text: m.text,
        duration: m.timer === false ? 0 : 6000,
        action: m.action ? { label: m.action, onClick: () => {} } : undefined,
      });
    });
    return el;
  },
};

/* ---------- Banner ---------- */

export const Banner = {
  parameters: { layout: "fullscreen", ...describe(null, "Page-wide state, placed under the top bar. Dismissible banners use `data-mh-dismissible` on the banner and `data-mh-dismiss` on the close button.") },
  render: () =>
    render(`<div class="sb-stack" style="gap: var(--mh-space-3); padding-block: var(--mh-space-4)">
      <div class="mh-banner mh-banner--hatch" data-tone="warn" role="status">
        <span class="mh-banner__icon">${icon("pause")}</span>
        <span class="mh-banner__text"><b>Outer Rim Guild is paused.</b> New claims are blocked by proposal #31 while SSU-08's lease is renewed. Hauls already claimed can finish and settle.</span>
        <button type="button" class="mh-link">Read proposal</button>
      </div>
      <div class="mh-banner" data-tone="info" data-mh-dismissible>
        <span class="mh-banner__icon">${icon("info")}</span>
        <span class="mh-banner__text"><b>Testnet.</b> Networks, cargo and CR here are test assets. No delivery adapter is certified for production.</span>
        <button type="button" class="mh-toast__close" data-mh-dismiss aria-label="Dismiss testnet notice">${icon("cross")}</button>
      </div>
      <div class="mh-banner" data-tone="alert" data-mh-dismissible role="alert">
        <span class="mh-banner__icon">${icon("alert")}</span>
        <span class="mh-banner__text"><b>Adapter revoked.</b> "Manual attest (retired)" can no longer certify deliveries on ORG. Pending deliveries need another adapter.</span>
        <button type="button" class="mh-link">See adapters</button>
        <button type="button" class="mh-toast__close" data-mh-dismiss aria-label="Dismiss adapter notice">${icon("cross")}</button>
      </div>
    </div>`),
};

/* ---------- Notice ---------- */

const notice = (tone, iconName, title, text) => `<div class="mh-plate mh-notice" data-tone="${tone}">
  <span class="mh-notice__icon">${icon(iconName)}</span>
  <span class="mh-notice__title">${title}</span>
  <p>${text}</p>
</div>`;

export const Notice = {
  render: () =>
    render(`<div class="sb-stack" style="max-width: 640px">
      ${notice("info", "info", "Collateral is not cargo valuation", "The minimum is a share of the reward (50% here, rounded up), posted in the reward asset. It does not price the cargo you carry.")}
      ${notice("warn", "warning", "Leased endpoint ends before the deadline", "SSU-03 Cinder Relay leaves the network on 22 Oct 01:00. MH-0238's haul runs 12h, so delivery could land after the lease ends.")}
      ${notice("alert", "adapter", "Delivery needs a certified adapter", "Withdrawing the manifest must be certified by a trusted adapter in the same transaction. No production adapter exists yet.")}
      ${notice("ok", "check", "Settled", "MH-0234 paid 11,475 CR to the hauler and 2,025 CR to the treasury. Collateral returned.")}
    </div>`),
};

/* ---------- Dialog ---------- */

export const Dialog = {
  render: () => {
    const id = uid("claim");
    const deadline = NOW + job0248.haulDurationMs;
    const el = render(`<div class="sb-stack">
      <div class="sb-row">
        <button type="button" class="mh-plate mh-button" data-mh-dialog-open="${id}"><span class="mh-button__label">Claim MH-0248</span></button>
        <span class="sb-caption">Opens a native modal: focus moves in, Escape or the backdrop closes it.</span>
      </div>
      <dialog class="mh-plate mh-plate--lg mh-dialog" id="${id}" aria-labelledby="${id}-t">
        <div class="mh-dialog__head">
          <div><span class="mh-label">Transfer · MH-0248</span><h2 class="mh-dialog__title" id="${id}-t">Claim this haul?</h2></div>
          <button type="button" class="mh-plate mh-iconbtn mh-iconbtn--sm" data-mh-dialog-close aria-label="Close">${icon("cross")}</button>
        </div>
        <div class="mh-dialog__body">
          <p>Refined ore, 2,400 u, from SSU-01 Aster Prime to SSU-04 Meridian Outpost.</p>
          <dl class="mh-kv">
            <div><dt>Reward</dt><dd>${int.format(job0248.reward)} CR</dd></div>
            <div><dt>Your share (85%)</dt><dd>${int.format(Math.floor(job0248.reward * 0.85))} CR</dd></div>
            <div><dt>Collateral to post</dt><dd>${int.format(collateral)} CR</dd></div>
            <div><dt>Haul window</dt><dd>${formatSpan(job0248.haulDurationMs)}</dd></div>
            <div><dt>Deadline if claimed now</dt><dd>${formatTime(deadline)} UTC</dd></div>
          </dl>
          ${notice("warn", "warning", "Expiry after claim opens a dispute", "If you miss the deadline, governance decides. A ruling against you pays part of your collateral to the lister.")}
          <label class="mh-check"><input type="checkbox" data-ack> I've read the manifest and can collect at SSU-01</label>
        </div>
        <div class="mh-dialog__foot">
          <button type="button" class="mh-plate mh-button mh-button--ghost" data-mh-dialog-close="cancel"><span class="mh-button__label">Cancel</span></button>
          <button type="button" class="mh-plate mh-button" data-claim disabled><span class="mh-button__label">Claim · post ${int.format(collateral)} CR</span><span class="mh-button__cells" aria-hidden="true"><i></i><i></i><i></i></span></button>
        </div>
      </dialog>
    </div>`);
    const claim = el.querySelector("[data-claim]");
    el.querySelector("[data-ack]").addEventListener("change", (e) => (claim.disabled = !e.target.checked));
    claim.addEventListener("click", () => {
      claim.setAttribute("aria-busy", "true");
      setTimeout(() => {
        claim.removeAttribute("aria-busy");
        el.querySelector("dialog").close("claimed");
      }, 1400);
    });
    return el;
  },
  parameters: describe(null, "Confirmation for the one action that posts collateral. The primary action stays disabled until the acknowledgement is ticked."),
};

/* ---------- Tooltip ---------- */

export const Tooltip = {
  render: () => {
    const a = uid("tip");
    const b = uid("tip");
    const c = uid("tip");
    return render(`<div class="sb-row" style="padding-top: 56px; gap: var(--mh-space-6)">
      <span class="mh-tip-anchor">
        <button type="button" class="mh-plate mh-iconbtn" aria-label="Refresh board" aria-describedby="${a}">${icon("refresh")}</button>
        <span class="mh-tip" role="tooltip" id="${a}">Refresh board · last synced 16:00 UTC</span>
      </span>
      <span class="mh-tip-anchor">
        <button type="button" class="mh-plate mh-iconbtn" aria-label="Leased endpoint" aria-describedby="${b}">${icon("warning")}</button>
        <span class="mh-tip" role="tooltip" id="${b}">SSU-03's lease ends before this haul's deadline</span>
      </span>
      <span class="mh-tip-anchor">
        <span class="mh-id" tabindex="0" aria-describedby="${c}"><span class="mh-id__label">Treasury</span><code>0x8b3d…0b15</code></span>
        <span class="mh-tip" role="tooltip" id="${c}">0x8b3d1f6e9a2c4b7d0e5f8a1c3b6d9e2f4a7c0b15</span>
      </span>
    </div>
    <p class="sb-caption">Shown on hover and keyboard focus, hidden with Escape without moving focus. Tooltips add detail; the control's own label must already say what it does.</p>`);
  },
};

/* ---------- Transaction flow ---------- */

const STEPS = ["Build", "Sign", "Submit", "Confirmed"];
const cell = (state, i) =>
  state === "done" ? icon("check") : state === "failed" ? icon("cross") : state === "active" ? spinner() : String(i + 1);
const flow = (states, label) =>
  `<ol class="mh-txflow" aria-label="${label}">${STEPS.map((s, i) => `<li data-state="${states[i]}"${states[i] === "active" ? ' aria-current="step"' : ""}><span class="mh-txflow__cell">${cell(states[i], i)}</span>${s}</li>`).join("")}</ol>`;

export const TxFlow = {
  name: "Transaction flow",
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-section"><span class="mh-label">Waiting for signature</span>${flow(["done", "active", "todo", "todo"], "Claim transaction")}</div>
      <div class="sb-section"><span class="mh-label">Confirmed</span>${flow(["done", "done", "done", "done"], "Claim transaction")}</div>
      <div class="sb-section"><span class="mh-label">Rejected in wallet</span>${flow(["done", "failed", "todo", "todo"], "Claim transaction")}
        ${notice("alert", "alert", "Signature rejected", "Nothing was submitted and no collateral moved. You can try again.")}</div>
    </div>`),
  parameters: describe(null, "Every Minehaul action is one Sui transaction. Show where it is: built, waiting for a wallet signature, submitted, confirmed. The active cell carries the spinner."),
};

export const TxFlowPlay = {
  name: "Transaction flow · play",
  render: () => {
    const el = render(`<div class="sb-stack" style="max-width: 640px">
      <div class="sb-row"><button type="button" class="mh-plate mh-button mh-button--sm" data-play><span class="mh-button__label">Claim MH-0248</span></button><button type="button" class="mh-link" data-fail>Play a rejected signature</button></div>
      <div data-flow aria-live="polite">${flow(["todo", "todo", "todo", "todo"], "Claim transaction")}</div>
      <div data-result></div>
    </div>`);
    let timer;
    const play = (failAt) => {
      clearTimeout(timer);
      const result = el.querySelector("[data-result]");
      result.innerHTML = "";
      let step = 0;
      const tick = () => {
        if (!el.isConnected && step) return;
        const states = STEPS.map((_, i) => (i < step ? "done" : i === step ? (step === failAt ? "failed" : "active") : "todo"));
        if (step >= STEPS.length) states.fill("done");
        el.querySelector("[data-flow]").innerHTML = flow(states, "Claim transaction");
        if (step === failAt) {
          result.innerHTML = notice("alert", "alert", "Signature rejected", "Nothing was submitted and no collateral moved.");
          return;
        }
        if (step >= STEPS.length) {
          result.innerHTML = notice("ok", "check", "Claimed MH-0248", `${int.format(collateral)} CR posted. Haul deadline in 8h.`);
          return;
        }
        step += 1;
        timer = setTimeout(tick, step === 2 ? 1600 : 900);
      };
      tick();
    };
    el.querySelector("[data-play]").addEventListener("click", () => play(-1));
    el.querySelector("[data-fail]").addEventListener("click", () => play(1));
    return el;
  },
};

/* ---------- Loading ---------- */

export const Loading = {
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-section">
        <span class="mh-label">Spinner</span>
        <div class="sb-row" style="gap: var(--mh-space-5)">
          <span role="status" class="sb-row" style="gap: 8px">${spinner()}<span class="mh-muted" style="font-size: var(--mh-text-xs)">Syncing board…</span></span>
          <span role="status" aria-label="Loading">${spinner("mh-spinner--lg")}</span>
        </div>
      </div>
      <div class="sb-section">
        <span class="mh-label">Busy bar</span>
        <div role="progressbar" aria-label="Fetching network events" class="mh-busybar" style="max-width: 420px"></div>
      </div>
      <div class="sb-section" aria-busy="true" aria-label="Loading job">
        <span class="mh-label">Skeleton · job card</span>
        <div class="mh-plate mh-plate--tl-br mh-plate--lg" style="--mh-plate-fill: var(--mh-surface); padding: var(--mh-space-5); display: grid; gap: var(--mh-space-4); max-width: 640px">
          <span class="mh-skel" style="width: 30%"></span>
          <span class="mh-skel mh-skel--title"></span>
          <div class="sb-row" style="flex-wrap: nowrap"><span class="mh-skel mh-skel--block" style="flex:1; height: 84px"></span><span class="mh-skel mh-skel--block" style="flex:1; height: 84px"></span></div>
          <div class="sb-row" style="flex-wrap: nowrap">${'<span class="mh-skel" style="flex:1; height: 40px"></span>'.repeat(4)}</div>
        </div>
      </div>
      <div class="sb-section" aria-busy="true" aria-label="Loading jobs">
        <span class="mh-label">Skeleton · table rows</span>
        <div style="display: grid; gap: 10px; max-width: 640px">
          ${[70, 55, 80, 62].map((w) => `<div class="sb-row" style="flex-wrap: nowrap"><span class="mh-skel mh-skel--cell"></span><span class="mh-skel" style="width: ${w}%"></span><span class="mh-skel" style="width: 12%; margin-left: auto"></span></div>`).join("")}
        </div>
      </div>
    </div>`),
};

/* ---------- Empty ---------- */

export const Empty = {
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 280px">
      <div class="mh-empty">
        <span class="mh-empty__icon">${icon("stacks")}</span>
        <h3 class="mh-empty__title">No jobs at 30 CR/u</h3>
        <p>None of the 11 open jobs pays your floor. The best rate right now is 26.72 CR/u on MH-0245.</p>
        <button type="button" class="mh-plate mh-button mh-button--secondary mh-button--sm"><span class="mh-button__label">Lower floor to 26.5</span></button>
      </div>
      <div class="mh-empty">
        <span class="mh-empty__icon">${icon("cargo")}</span>
        <h3 class="mh-empty__title">No hauls yet</h3>
        <p>Claim a job from the board. Your hauls, deadlines and dispute windows show up here.</p>
        <button type="button" class="mh-plate mh-button mh-button--sm"><span class="mh-button__label">Open the board</span></button>
      </div>
      <div class="mh-empty">
        <span class="mh-empty__icon">${icon("node")}</span>
        <h3 class="mh-empty__title">No endpoints registered</h3>
        <p>A network needs at least two registered SSUs before it can list a Transfer. Registration goes through governance.</p>
        <button type="button" class="mh-plate mh-button mh-button--brand mh-button--sm"><span class="mh-button__label">Propose an SSU</span></button>
      </div>
    </div>`),
};
